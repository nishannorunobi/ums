package com.ums.config;

import com.ums.security.UserPrincipal;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.util.UUID;

/** Allows SpEL expressions like @userSecurity.isOwner(#id) in @PreAuthorize. */
@Component("userSecurity")
public class UserSecurity {

    public boolean isOwner(UUID resourceUserId) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof UserPrincipal up)) return false;
        return up.getId().equals(resourceUserId);
    }
}
