package com.kaiwu.module.identity.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.repository.UserRepository;
import com.kaiwu.module.identity.service.UserService;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.starter.KaiwuContext;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Updates a user's display name while preserving the existing email and immutable username. */
@Component
public final class UserDisplayNameUpdateAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> PREVIEW_FIELDS =
            Set.of("targetUserId", "username", "currentDisplayName", "displayName");
    private final UserService service;
    private final UserRepository repository;

    public UserDisplayNameUpdateAgentWriteHandler(UserService service, UserRepository repository) {
        this.service = service;
        this.repository = repository;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.USER_DISPLAY_NAME_UPDATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("targetUserId", "displayName").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("用户参数不合法");
        if (!(parameters.get("targetUserId") instanceof String userId) || !userId.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("用户 ID 不合法");
        try {
            Long.parseLong(userId);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("用户 ID 不合法", invalid);
        }
        if (!(parameters.get("displayName") instanceof String rawName)) throw new IllegalArgumentException("显示名称不合法");
        String displayName = rawName.trim();
        if (displayName.isEmpty() || displayName.length() > 100) throw new IllegalArgumentException("显示名称不合法");
        Map<String, Object> normalized = new LinkedHashMap<>();
        normalized.put("targetUserId", userId);
        normalized.put("displayName", displayName);
        return normalized;
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
                "currentDisplayName",
                target.displayName(),
                "displayName",
                (String) parameters.get("displayName"));
    }

    @Override
    public LocalAgentWriteResult executeForAction(
            Map<String, Object> parameters,
            Map<String, String> previewFields,
            KaiwuContext actor,
            RequestMetadata metadata) {
        Map<String, Object> normalized;
        try {
            normalized = normalize(parameters);
        } catch (IllegalArgumentException invalid) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "操作参数不合法", "api.agent.actionParameters");
        }
        if (previewFields == null
                || !previewFields.keySet().equals(PREVIEW_FIELDS)
                || !Objects.equals(normalized.get("targetUserId"), previewFields.get("targetUserId"))
                || !Objects.equals(normalized.get("displayName"), previewFields.get("displayName")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String userId = (String) normalized.get("targetUserId");
        service.updateDisplayNameForAgent(
                userId,
                (String) normalized.get("displayName"),
                previewFields.get("currentDisplayName"),
                actor,
                metadata);
        return new LocalAgentWriteResult(userId, null);
    }
}
