package com.ums.service;

import com.ums.dto.request.ChangePasswordRequest;
import com.ums.dto.request.CreateUserRequest;
import com.ums.dto.request.UpdateUserRequest;
import com.ums.dto.response.PagedResponse;
import com.ums.dto.response.UserResponse;

import java.util.UUID;

public interface UserService {

    UserResponse createUser(CreateUserRequest request);

    UserResponse getUserById(UUID id);

    UserResponse getUserByUsername(String username);

    PagedResponse<UserResponse> getAllUsers(int page, int size, String sortBy, String search);

    UserResponse updateUser(UUID id, UpdateUserRequest request);

    void deleteUser(UUID id);

    void changePassword(UUID id, ChangePasswordRequest request);
}
