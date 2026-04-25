package com.ums.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ums.api.v1.UserController;
import com.ums.dto.request.CreateUserRequest;
import com.ums.dto.response.UserResponse;
import com.ums.service.UserService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired MockMvc     mockMvc;
    @Autowired ObjectMapper mapper;

    @MockBean UserService userService;

    @Test
    @WithMockUser(roles = "ADMIN")
    void createUser_returns201() throws Exception {
        CreateUserRequest req = new CreateUserRequest();
        req.setUsername("alice");
        req.setEmail("alice@example.com");
        req.setPassword("Secret@1234");

        UserResponse response = UserResponse.builder()
                .id(UUID.randomUUID())
                .username("alice")
                .email("alice@example.com")
                .enabled(true)
                .build();

        when(userService.createUser(any())).thenReturn(response);

        mockMvc.perform(post("/api/v1/users")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(req)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.username").value("alice"))
                .andExpect(jsonPath("$.email").value("alice@example.com"));
    }

    @Test
    @WithMockUser(roles = "USER")
    void createUser_forbidden_forNonAdmin() throws Exception {
        CreateUserRequest req = new CreateUserRequest();
        req.setUsername("bob");
        req.setEmail("bob@example.com");
        req.setPassword("Secret@1234");

        mockMvc.perform(post("/api/v1/users")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());
    }
}
