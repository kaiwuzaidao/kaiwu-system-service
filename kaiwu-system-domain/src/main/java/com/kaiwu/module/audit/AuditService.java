package com.kaiwu.module.audit;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.audit.mapper.AuditWriteMapper;
import com.kaiwu.port.AuditPort;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;

/**
 * 登录与平台写操作审计。任何日志都不得保存密码、Token 或密码哈希。
 */
@Service
public class AuditService implements AuditPort {

    private final AuditWriteMapper auditMapper;
    private final ObjectMapper objectMapper;

    public AuditService(AuditWriteMapper auditMapper, ObjectMapper objectMapper) {
        this.auditMapper = auditMapper;
        this.objectMapper = objectMapper;
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordLogin(String username, String userId, String status, String message, RequestMetadata metadata) {
        auditMapper.insertLoginLog(
                username,
                userId,
                status,
                trim(message, 255),
                trim(metadata.clientIp(), 64),
                trim(metadata.traceId(), 64));
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordOperation(
            KaiwuContext actor, String operation, String path, String detail, RequestMetadata metadata) {
        recordOperation(actor, "user", operation, path, detail, metadata);
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordOperation(
            KaiwuContext actor, String module, String operation, String path, String detail, RequestMetadata metadata) {
        writeOperation(actor, module, operation, path, detail, metadata);
    }

    /**
     * 记录必须与调用方业务写入同成败的成功审计。
     *
     * <p>只允许在已有事务中调用，防止业务最终提交失败时留下“操作成功”记录。
     * 调用方不得先锁定同一用户行；修改用户本身的流程应继续使用独立审计方法，避免
     * `sys_user` 用户名查询发生自等待。</p>
     */
    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void recordOperationInCallerTransaction(
            KaiwuContext actor, String module, String operation, String path, String detail, RequestMetadata metadata) {
        writeOperation(actor, module, operation, path, detail, metadata);
    }

    private void writeOperation(
            KaiwuContext actor, String module, String operation, String path, String detail, RequestMetadata metadata) {
        // 不用 INSERT ... SELECT，避免 MySQL 把用户名读取升级为锁定读。
        // REQUIRES_NEW 路径可读取最后提交的用户名；加入调用方事务的路径只供未修改
        // sys_user 的业务（例如 scheduler）使用。
        String username = auditMapper.findUsername(actor.userId());
        auditMapper.insertOperationLog(
                actor.userId(),
                username,
                module,
                operation,
                path,
                trim(detail, 1000),
                trim(metadata.clientIp(), 64),
                trim(metadata.traceId(), 64));
    }

    /**
     * 记录带字段级 diff 的写操作。旧 recordOperation 完全保留兼容，未迁移的调用点不受影响。
     * <p>detail 由 changes 自动生成简短摘要，前端无法解析 change_json 时仍能看到"改了什么"。
     * targetType/targetId 用于按目标资源检索历史变更（表已加复合索引）。</p>
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordOperationWithDiff(
            KaiwuContext actor,
            String module,
            String operation,
            String path,
            String targetType,
            String targetId,
            List<FieldChange> changes,
            RequestMetadata metadata) {
        String username = auditMapper.findUsername(actor.userId());
        String changeJson = serializeChanges(changes);
        String detail = summarizeChanges(changes);
        auditMapper.insertOperationLogWithDiff(
                actor.userId(),
                username,
                module,
                operation,
                path,
                trim(detail, 1000),
                trim(targetType, 64),
                trim(targetId, 64),
                changeJson,
                trim(metadata.clientIp(), 64),
                trim(metadata.traceId(), 64));
    }

    private String serializeChanges(List<FieldChange> changes) {
        if (changes == null || changes.isEmpty()) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(changes);
        } catch (Exception exception) {
            // 审计不能因序列化失败而丢主记录，回退到 null 并保留 detail 摘要
            return null;
        }
    }

    private static String summarizeChanges(List<FieldChange> changes) {
        // 提交了但字段值没变也要留下可读记录：detail 为空会让操作日志列表出现空白行，
        // 无法区分"没改动"和"审计写坏了"。change_json 仍为 null，前端 diff 入口保持禁用。
        if (changes == null || changes.isEmpty()) {
            return "无字段变更";
        }
        StringBuilder builder = new StringBuilder();
        for (FieldChange change : changes) {
            if (builder.length() > 0) {
                builder.append("; ");
            }
            builder.append(change.field())
                    .append(": ")
                    .append(display(change.before()))
                    .append(" -> ")
                    .append(display(change.after()));
        }
        return builder.toString();
    }

    private static String display(String value) {
        return value == null ? "null" : value;
    }

    private static String trim(String value, int maxLength) {
        if (value == null || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }
}
