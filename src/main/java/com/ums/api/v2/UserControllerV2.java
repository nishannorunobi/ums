package com.ums.api.v2;

import com.ums.dto.response.PagedResponse;
import com.ums.dto.response.UserResponse;
import com.ums.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * v2 adds cursor-style sort options and exposes additional user fields.
 * Extend this controller as v2-specific features grow.
 */
@RestController
@RequestMapping("/api/v2/users")
@RequiredArgsConstructor
@Tag(name = "Users v2", description = "Enhanced user operations (v2)")
@SecurityRequirement(name = "bearerAuth")
public class UserControllerV2 {

    private final UserService userService;

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'MODERATOR')")
    @Operation(summary = "List users — v2 with richer sort options")
    public ResponseEntity<PagedResponse<UserResponse>> list(
            @RequestParam(defaultValue = "0")   int page,
            @RequestParam(defaultValue = "20")  int size,
            @RequestParam(defaultValue = "username") String sortBy,
            @RequestParam(required = false)     String search) {
        return ResponseEntity.ok(userService.getAllUsers(page, size, sortBy, search));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'MODERATOR') or @userSecurity.isOwner(#id)")
    @Operation(summary = "Get user by ID — v2")
    public ResponseEntity<UserResponse> getById(@PathVariable UUID id) {
        return ResponseEntity.ok(userService.getUserById(id));
    }
}
