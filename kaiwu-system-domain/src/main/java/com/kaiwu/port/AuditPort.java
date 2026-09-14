package com.kaiwu.port;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.starter.KaiwuContext;

/** 跨模块写审计的稳定边界。 */
public interface AuditPort {

    void recordLogin(String username, String userId, String status, String message, RequestMetadata metadata);

    void recordOperation(KaiwuContext actor, String operation, String path, String detail, RequestMetadata metadata);

    void recordOperation(
            KaiwuContext actor, String module, String operation, String path, String detail, RequestMetadata metadata);

    void recordOperationInCallerTransaction(
            KaiwuContext actor, String module, String operation, String path, String detail, RequestMetadata metadata);
}
