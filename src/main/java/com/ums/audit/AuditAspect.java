package com.ums.audit;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ums.security.UserPrincipal;
import com.ums.service.AuditService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.UUID;

@Slf4j
@Aspect
@Component
@RequiredArgsConstructor
public class AuditAspect {

    private final AuditService  auditService;
    private final ObjectMapper  objectMapper;

    @Around("@annotation(auditable)")
    public Object audit(ProceedingJoinPoint pjp, Auditable auditable) throws Throwable {
        String entityId  = extractEntityId(pjp.getArgs());
        String oldValue  = null;
        String newValue  = null;
        String userId    = null;
        String username  = null;

        var authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.getPrincipal() instanceof UserPrincipal up) {
            userId   = up.getId().toString();
            username = up.getUsername();
        }

        Object result = pjp.proceed();

        try {
            newValue = objectMapper.writeValueAsString(result);
        } catch (Exception ignored) {}

        String ipAddress  = resolveIp();
        String requestId  = UUID.randomUUID().toString();

        auditService.log(auditable.action(), auditable.entityType(), entityId,
                userId, username, oldValue, newValue, ipAddress, requestId);

        return result;
    }

    private String extractEntityId(Object[] args) {
        for (Object arg : args) {
            if (arg instanceof UUID)   return arg.toString();
            if (arg instanceof String s && s.length() <= 100) return s;
        }
        return null;
    }

    private String resolveIp() {
        try {
            var attrs = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
            if (attrs != null) {
                HttpServletRequest req = attrs.getRequest();
                String xfwd = req.getHeader("X-Forwarded-For");
                return (xfwd != null && !xfwd.isBlank()) ? xfwd.split(",")[0].trim() : req.getRemoteAddr();
            }
        } catch (Exception ignored) {}
        return "unknown";
    }
}
