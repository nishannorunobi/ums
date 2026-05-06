package com.ums.api.admin;

import com.ums.domain.User;
import com.ums.dto.admin.*;
import com.ums.dto.request.CreateUserRequest;
import com.ums.exception.ConflictException;
import com.ums.exception.ResourceNotFoundException;
import com.ums.repository.UserRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin")
@CrossOrigin(origins = { "http://localhost:3000", "http://localhost:5173" })
@Tag(name = "Admin", description = "Customer-care admin endpoints for user management")
public class AdminUserController {

    private final UserRepository userRepository;

    public AdminUserController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    // ── Stats ──────────────────────────────────────────────────────────────────

    @Operation(summary = "Dashboard stats — totals, enabled/disabled, recent registrations")
    @GetMapping("/stats")
    public AdminStatsResponse getStats() {
        LocalDateTime now = LocalDateTime.now();
        long total    = userRepository.count();
        long enabled  = userRepository.countByEnabled(true);
        long today    = userRepository.countByCreatedAtAfter(now.toLocalDate().atStartOfDay());
        long week     = userRepository.countByCreatedAtAfter(now.minusWeeks(1));
        long month    = userRepository.countByCreatedAtAfter(now.minusMonths(1));

        AdminStatsResponse s = new AdminStatsResponse();
        s.setTotal(total);
        s.setEnabled(enabled);
        s.setDisabled(total - enabled);
        s.setNewToday(today);
        s.setNewThisWeek(week);
        s.setNewThisMonth(month);
        return s;
    }

    // ── List / search ──────────────────────────────────────────────────────────

    @Operation(summary = "List users — paginated, optional full-text search")
    @GetMapping("/users")
    public AdminPagedResponse listUsers(
            @RequestParam(defaultValue = "") String search,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "createdAt") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir) {

        Sort sort = sortDir.equalsIgnoreCase("asc")
                ? Sort.by(sortBy).ascending()
                : Sort.by(sortBy).descending();
        PageRequest pageable = PageRequest.of(page, size, sort);

        Page<User> result = search.isBlank()
                ? userRepository.findAll(pageable)
                : userRepository.search(search, pageable);

        List<AdminUserResponse> users = result.getContent().stream()
                .map(this::toResponse).toList();
        return new AdminPagedResponse(users, page, size, result.getTotalElements());
    }

    // ── Single user ────────────────────────────────────────────────────────────

    @Operation(summary = "Get a single user by ID")
    @GetMapping("/users/{id}")
    public AdminUserResponse getUser(@PathVariable UUID id) {
        return toResponse(findById(id));
    }

    // ── Create ─────────────────────────────────────────────────────────────────

    @Operation(summary = "Create a new user")
    @PostMapping("/users")
    public ResponseEntity<AdminUserResponse> createUser(@RequestBody CreateUserRequest req) {
        if (userRepository.existsByUsername(req.getUsername()))
            throw new ConflictException("Username already taken: " + req.getUsername());
        if (userRepository.existsByEmail(req.getEmail()))
            throw new ConflictException("Email already in use: " + req.getEmail());

        User user = new User();
        user.setUsername(req.getUsername());
        user.setEmail(req.getEmail());
        user.setPassword(req.getPassword());
        user.setFirstName(req.getFirstName());
        user.setLastName(req.getLastName());
        user.setPhoneNumber(req.getPhoneNumber());
        return ResponseEntity.status(HttpStatus.CREATED).body(toResponse(userRepository.save(user)));
    }

    // ── Update ─────────────────────────────────────────────────────────────────

    @Operation(summary = "Update user details")
    @PutMapping("/users/{id}")
    public AdminUserResponse updateUser(@PathVariable UUID id,
                                        @RequestBody AdminUpdateUserRequest req) {
        User user = findById(id);
        if (req.getEmail() != null && !req.getEmail().equals(user.getEmail())) {
            if (userRepository.existsByEmail(req.getEmail()))
                throw new ConflictException("Email already in use: " + req.getEmail());
            user.setEmail(req.getEmail());
        }
        if (req.getFirstName()   != null) user.setFirstName(req.getFirstName());
        if (req.getLastName()    != null) user.setLastName(req.getLastName());
        if (req.getPhoneNumber() != null) user.setPhoneNumber(req.getPhoneNumber());
        if (req.getEnabled()     != null) user.setEnabled(req.getEnabled());
        return toResponse(userRepository.save(user));
    }

    // ── Enable / disable ───────────────────────────────────────────────────────

    @Operation(summary = "Enable a user account")
    @PatchMapping("/users/{id}/enable")
    public AdminUserResponse enableUser(@PathVariable UUID id) {
        User user = findById(id);
        user.setEnabled(true);
        return toResponse(userRepository.save(user));
    }

    @Operation(summary = "Disable a user account")
    @PatchMapping("/users/{id}/disable")
    public AdminUserResponse disableUser(@PathVariable UUID id) {
        User user = findById(id);
        user.setEnabled(false);
        return toResponse(userRepository.save(user));
    }

    // ── Reset password ─────────────────────────────────────────────────────────

    @Operation(summary = "Reset a user's password (plain-text; hash before production use)")
    @PatchMapping("/users/{id}/reset-password")
    public ResponseEntity<Void> resetPassword(@PathVariable UUID id,
                                              @RequestBody ResetPasswordRequest req) {
        User user = findById(id);
        user.setPassword(req.getNewPassword());
        userRepository.save(user);
        return ResponseEntity.noContent().build();
    }

    // ── Delete ─────────────────────────────────────────────────────────────────

    @Operation(summary = "Delete a user permanently")
    @DeleteMapping("/users/{id}")
    public ResponseEntity<Void> deleteUser(@PathVariable UUID id) {
        userRepository.delete(findById(id));
        return ResponseEntity.noContent().build();
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private User findById(UUID id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", id.toString()));
    }

    private AdminUserResponse toResponse(User u) {
        AdminUserResponse r = new AdminUserResponse();
        r.setId(u.getId());
        r.setUsername(u.getUsername());
        r.setEmail(u.getEmail());
        r.setFirstName(u.getFirstName());
        r.setLastName(u.getLastName());
        r.setPhoneNumber(u.getPhoneNumber());
        r.setEnabled(u.isEnabled());
        r.setCreatedAt(u.getCreatedAt());
        r.setUpdatedAt(u.getUpdatedAt());
        return r;
    }
}
