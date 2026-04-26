package com.ums.service;

import com.ums.dto.request.CreateUserRequest;
import com.ums.dto.request.UpdateUserRequest;
import com.ums.dto.response.UserResponse;

import java.util.List;
import java.util.UUID;

public interface UserService {

    UserResponse createUser(CreateUserRequest request);

    List<UserResponse> getAllUsers();

    UserResponse getUserById(UUID id);

    UserResponse updateUser(UUID id, UpdateUserRequest request);

    void deleteUser(UUID id);
}
