package com.ums.service;

import com.ums.domain.ERole;
import com.ums.domain.Role;
import com.ums.domain.User;
import com.ums.dto.request.ChangePasswordRequest;
import com.ums.dto.request.CreateUserRequest;
import com.ums.dto.request.UpdateUserRequest;
import com.ums.dto.response.PagedResponse;
import com.ums.dto.response.UserResponse;
import com.ums.exception.ConflictException;
import com.ums.exception.ResourceNotFoundException;
import com.ums.mapper.UserMapper;
import com.ums.repository.RoleRepository;
import com.ums.repository.UserRepository;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional
public class UserServiceImpl implements UserService {

    private final UserRepository   userRepository;
    private final RoleRepository   roleRepository;
    private final UserMapper       userMapper;
    private final PasswordEncoder  passwordEncoder;

    @Override
    public UserResponse createUser(CreateUserRequest request) {
        if (userRepository.existsByUsername(request.getUsername()))
            throw new ConflictException("Username already taken: " + request.getUsername());
        if (userRepository.existsByEmail(request.getEmail()))
            throw new ConflictException("Email already in use: " + request.getEmail());

        User user = User.builder()
                .username(request.getUsername())
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .firstName(request.getFirstName())
                .lastName(request.getLastName())
                .phoneNumber(request.getPhoneNumber())
                .roles(resolveRoles(request.getRoles()))
                .build();

        return userMapper.toResponse(userRepository.save(user));
    }

    @Override
    @Transactional(readOnly = true)
    @Cacheable(value = "users", key = "#id")
    @CircuitBreaker(name = "userService")
    @Retry(name = "userService")
    public UserResponse getUserById(UUID id) {
        return userMapper.toResponse(findUserById(id));
    }

    @Override
    @Transactional(readOnly = true)
    public UserResponse getUserByUsername(String username) {
        return userRepository.findByUsername(username)
                .map(userMapper::toResponse)
                .orElseThrow(() -> new ResourceNotFoundException("User", "username", username));
    }

    @Override
    @Transactional(readOnly = true)
    public PagedResponse<UserResponse> getAllUsers(int page, int size, String sortBy, String search) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(sortBy).ascending());
        Page<User> users  = userRepository.searchUsers(search, pageable);
        return PagedResponse.<UserResponse>builder()
                .content(users.getContent().stream().map(userMapper::toResponse).toList())
                .page(users.getNumber())
                .size(users.getSize())
                .totalElements(users.getTotalElements())
                .totalPages(users.getTotalPages())
                .last(users.isLast())
                .build();
    }

    @Override
    @CacheEvict(value = "users", key = "#id")
    public UserResponse updateUser(UUID id, UpdateUserRequest request) {
        User user = findUserById(id);

        if (request.getEmail() != null && !request.getEmail().equals(user.getEmail())) {
            if (userRepository.existsByEmail(request.getEmail()))
                throw new ConflictException("Email already in use: " + request.getEmail());
            user.setEmail(request.getEmail());
        }
        if (request.getFirstName()   != null) user.setFirstName(request.getFirstName());
        if (request.getLastName()    != null) user.setLastName(request.getLastName());
        if (request.getPhoneNumber() != null) user.setPhoneNumber(request.getPhoneNumber());
        if (request.getEnabled()     != null) user.setEnabled(request.getEnabled());
        if (request.getRoles()       != null) user.setRoles(resolveRoles(request.getRoles()));

        return userMapper.toResponse(userRepository.save(user));
    }

    @Override
    @CacheEvict(value = "users", key = "#id")
    public void deleteUser(UUID id) {
        User user = findUserById(id);
        userRepository.delete(user);
    }

    @Override
    public void changePassword(UUID id, ChangePasswordRequest request) {
        User user = findUserById(id);
        if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPassword()))
            throw new IllegalArgumentException("Current password is incorrect");
        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
    }

    private User findUserById(UUID id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", id.toString()));
    }

    private Set<Role> resolveRoles(Set<String> roleNames) {
        Set<Role> roles = new HashSet<>();
        if (roleNames == null || roleNames.isEmpty()) {
            roles.add(getRole(ERole.ROLE_USER));
        } else {
            for (String name : roleNames) {
                ERole eRole = switch (name.toUpperCase()) {
                    case "ADMIN"     -> ERole.ROLE_ADMIN;
                    case "MODERATOR" -> ERole.ROLE_MODERATOR;
                    default          -> ERole.ROLE_USER;
                };
                roles.add(getRole(eRole));
            }
        }
        return roles;
    }

    private Role getRole(ERole eRole) {
        return roleRepository.findByName(eRole)
                .orElseThrow(() -> new ResourceNotFoundException("Role", "name", eRole.name()));
    }
}
