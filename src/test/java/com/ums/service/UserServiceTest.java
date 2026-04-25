package com.ums.service;

import com.ums.domain.ERole;
import com.ums.domain.Role;
import com.ums.domain.User;
import com.ums.dto.request.CreateUserRequest;
import com.ums.dto.response.UserResponse;
import com.ums.exception.ConflictException;
import com.ums.mapper.UserMapper;
import com.ums.repository.RoleRepository;
import com.ums.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock UserRepository  userRepository;
    @Mock RoleRepository  roleRepository;
    @Mock UserMapper      userMapper;
    @Mock PasswordEncoder passwordEncoder;

    @InjectMocks UserServiceImpl userService;

    private Role userRole;

    @BeforeEach
    void setUp() {
        userRole = new Role(ERole.ROLE_USER);
    }

    @Test
    void createUser_success() {
        CreateUserRequest req = new CreateUserRequest();
        req.setUsername("john");
        req.setEmail("john@example.com");
        req.setPassword("Secret@1");

        User savedUser = User.builder()
                .id(UUID.randomUUID())
                .username("john")
                .email("john@example.com")
                .build();

        UserResponse response = UserResponse.builder()
                .username("john")
                .email("john@example.com")
                .build();

        when(userRepository.existsByUsername("john")).thenReturn(false);
        when(userRepository.existsByEmail("john@example.com")).thenReturn(false);
        when(roleRepository.findByName(ERole.ROLE_USER)).thenReturn(Optional.of(userRole));
        when(passwordEncoder.encode(any())).thenReturn("hashed");
        when(userRepository.save(any())).thenReturn(savedUser);
        when(userMapper.toResponse(any())).thenReturn(response);

        UserResponse result = userService.createUser(req);

        assertThat(result.getUsername()).isEqualTo("john");
        verify(userRepository).save(any(User.class));
    }

    @Test
    void createUser_duplicateUsername_throws() {
        CreateUserRequest req = new CreateUserRequest();
        req.setUsername("john");
        req.setEmail("john@example.com");
        req.setPassword("Secret@1");

        when(userRepository.existsByUsername("john")).thenReturn(true);

        assertThatThrownBy(() -> userService.createUser(req))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("john");

        verify(userRepository, never()).save(any());
    }
}
