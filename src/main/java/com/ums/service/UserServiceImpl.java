package com.ums.service;

import com.ums.domain.User;
import com.ums.dto.request.CreateUserRequest;
import com.ums.dto.request.UpdateUserRequest;
import com.ums.dto.response.UserResponse;
import com.ums.exception.ConflictException;
import com.ums.exception.ResourceNotFoundException;
import com.ums.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@Transactional
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;

    public UserServiceImpl(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public UserResponse createUser(CreateUserRequest request) {
        if (userRepository.existsByUsername(request.getUsername()))
            throw new ConflictException("Username already taken: " + request.getUsername());
        if (userRepository.existsByEmail(request.getEmail()))
            throw new ConflictException("Email already in use: " + request.getEmail());

        User user = new User();
        user.setUsername(request.getUsername());
        user.setEmail(request.getEmail());
        user.setPassword(request.getPassword());
        user.setFirstName(request.getFirstName());
        user.setLastName(request.getLastName());
        user.setPhoneNumber(request.getPhoneNumber());

        return toResponse(userRepository.save(user));
    }

    @Override
    @Transactional(readOnly = true)
    public List<UserResponse> getAllUsers() {
        return userRepository.findAll().stream().map(this::toResponse).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public UserResponse getUserById(UUID id) {
        return toResponse(findById(id));
    }

    @Override
    public UserResponse updateUser(UUID id, UpdateUserRequest request) {
        User user = findById(id);

        if (request.getEmail() != null && !request.getEmail().equals(user.getEmail())) {
            if (userRepository.existsByEmail(request.getEmail()))
                throw new ConflictException("Email already in use: " + request.getEmail());
            user.setEmail(request.getEmail());
        }
        if (request.getFirstName()   != null) user.setFirstName(request.getFirstName());
        if (request.getLastName()    != null) user.setLastName(request.getLastName());
        if (request.getPhoneNumber() != null) user.setPhoneNumber(request.getPhoneNumber());
        if (request.getEnabled()     != null) user.setEnabled(request.getEnabled());

        return toResponse(userRepository.save(user));
    }

    @Override
    public void deleteUser(UUID id) {
        userRepository.delete(findById(id));
    }

    private User findById(UUID id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", id.toString()));
    }

    private UserResponse toResponse(User user) {
        UserResponse r = new UserResponse();
        r.setId(user.getId());
        r.setUsername(user.getUsername());
        r.setEmail(user.getEmail());
        r.setFirstName(user.getFirstName());
        r.setLastName(user.getLastName());
        r.setPhoneNumber(user.getPhoneNumber());
        r.setEnabled(user.isEnabled());
        r.setCreatedAt(user.getCreatedAt());
        r.setUpdatedAt(user.getUpdatedAt());
        return r;
    }
}
