package com.ums.service;

import com.ums.domain.AuditLog;
import com.ums.repository.AuditLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class AuditService {

    private final AuditLogRepository auditLogRepository;

    @Async
    public void log(String action, String entityType, String entityId,
                    String userId, String username,
                    String oldValue, String newValue,
                    String ipAddress, String requestId) {
        AuditLog log = AuditLog.builder()
                .action(action)
                .entityType(entityType)
                .entityId(entityId)
                .userId(userId)
                .username(username)
                .oldValue(oldValue)
                .newValue(newValue)
                .ipAddress(ipAddress)
                .requestId(requestId)
                .timestamp(LocalDateTime.now())
                .build();
        auditLogRepository.save(log);
    }
}
