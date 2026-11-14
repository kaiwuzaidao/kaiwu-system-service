package com.kaiwu.module.operation.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.operation.model.FieldChange;
import com.kaiwu.port.AuditPort;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface AuditService extends AuditPort {

    void recordLogin(String username, String userId, String status, String message, RequestMetadata metadata);

    void recordOperation(KaiwuContext actor, String operation, String path, String detail, RequestMetadata metadata);

    void recordOperation(
            KaiwuContext actor, String module, String operation, String path, String detail, RequestMetadata metadata);

    void recordOperationInCallerTransaction(
            KaiwuContext actor, String module, String operation, String path, String detail, RequestMetadata metadata);

    void recordOperationWithDiff(
            KaiwuContext actor,
            String module,
            String operation,
            String path,
            String targetType,
            String targetId,
            List<FieldChange> changes,
            RequestMetadata metadata);
}
