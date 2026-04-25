package com.ums.repository;

import com.ums.domain.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByUsername(String username);

    Optional<User> findByEmail(String email);

    boolean existsByUsername(String username);

    boolean existsByEmail(String email);

    @Query("SELECT u FROM User u WHERE " +
           "(:search IS NULL OR LOWER(u.username) LIKE LOWER(CONCAT('%',:search,'%')) " +
           "OR LOWER(u.email) LIKE LOWER(CONCAT('%',:search,'%')) " +
           "OR LOWER(u.firstName) LIKE LOWER(CONCAT('%',:search,'%')))")
    Page<User> searchUsers(@Param("search") String search, Pageable pageable);
}
