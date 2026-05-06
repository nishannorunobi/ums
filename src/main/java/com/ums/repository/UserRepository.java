package com.ums.repository;

import com.ums.domain.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByUsername(String username);

    boolean existsByUsername(String username);

    boolean existsByEmail(String email);

    @Query("""
        SELECT u FROM User u WHERE
          LOWER(u.username)    LIKE LOWER(CONCAT('%',:q,'%')) OR
          LOWER(u.email)       LIKE LOWER(CONCAT('%',:q,'%')) OR
          LOWER(u.firstName)   LIKE LOWER(CONCAT('%',:q,'%')) OR
          LOWER(u.lastName)    LIKE LOWER(CONCAT('%',:q,'%'))
        """)
    Page<User> search(@Param("q") String query, Pageable pageable);

    long countByEnabled(boolean enabled);

    long countByCreatedAtAfter(LocalDateTime after);
}
