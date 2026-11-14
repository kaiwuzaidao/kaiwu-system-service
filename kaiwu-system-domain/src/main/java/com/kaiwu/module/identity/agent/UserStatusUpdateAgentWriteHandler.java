package com.kaiwu.module.identity.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.repository.UserRepository;
import com.kaiwu.module.identity.service.UserService;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Enables or disables a platform user through the existing session-revoking business service. */
@Component
public final class UserStatusUpdateAgentWriteHandler implements LocalAgentWriteHandler {
    private final UserService service;
    private final UserRepository repository;

    public UserStatusUpdateAgentWriteHandler(UserService service, UserRepository repository) {
        this.service = service;
        this.repository = repository;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.USER_STATUS_UPDATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("targetUserId", "status").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("用户状态参数不合法");
        if (!(parameters.get("targetUserId") instanceof String userId) || !userId.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("用户 ID 不合法");
        try {
            Long.parseLong(userId);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("用户 ID 不合法", invalid);
        }
        if (!(parameters.get("status") instanceof String status)
                || !Set.of("ENABLED", "DISABLED").contains(status)) throw new IllegalArgumentException("目标状态不合法");
        return Map.of("targetUserId", userId, "status", status);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String userId = (String) parameters.get("targetUserId");
        var target = repository
                .findView(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "用户不存在", "api.user.notFound"));
        return Map.of(
                "targetUserId",
                userId,
                "username",
                target.username(),
                "currentStatus",
                target.status(),
                "status",
                (String) parameters.get("status"));
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return "DISABLED".equals(parameters.get("status")) ? ConfirmationMode.STRONG : ConfirmationMode.REQUIRED;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return confirmationMode(parameters) == ConfirmationMode.STRONG ? "停用 " + previewFields.get("username") : null;
    }

    @Override
    public String execute(Map<String, Object> parameters, KaiwuContext actor, RequestMetadata metadata) {
        String userId = (String) parameters.get("targetUserId");
        service.updateStatus(userId, (String) parameters.get("status"), actor, metadata);
        return userId;
    }
}
