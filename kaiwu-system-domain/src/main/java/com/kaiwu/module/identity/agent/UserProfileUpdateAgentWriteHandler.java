package com.kaiwu.module.identity.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.repository.UserRepository;
import com.kaiwu.module.identity.service.UserService;
import com.kaiwu.module.identity.service.UserService.UserProfileExpectation;
import com.kaiwu.module.user.dto.UserUpdateRequest;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.starter.KaiwuContext;
import jakarta.validation.Validator;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Replaces the editable platform-user profile after checking the frozen target. */
@Component
public final class UserProfileUpdateAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> FIELDS = Set.of("targetUserId", "displayName", "email");
    private static final Set<String> PREVIEW_FIELDS = Set.of(
            "targetUserId", "username", "currentDisplayName", "currentEmail", "currentStatus", "displayName", "email");
    private final UserRepository repository;
    private final UserService service;
    private final Validator validator;

    public UserProfileUpdateAgentWriteHandler(UserRepository repository, UserService service, Validator validator) {
        this.repository = repository;
        this.service = service;
        this.validator = validator;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.USER_PROFILE_UPDATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!FIELDS.equals(parameters.keySet())) throw new IllegalArgumentException("用户资料参数不完整");
        String userId = text(parameters.get("targetUserId"), 19);
        if (!userId.matches("[1-9][0-9]{0,18}")) throw new IllegalArgumentException("用户 ID 不合法");
        try {
            Long.parseLong(userId);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("用户 ID 不合法", invalid);
        }
        String displayName = text(parameters.get("displayName"), 100);
        String email = text(parameters.get("email"), 200);
        if (!validator.validate(new UserUpdateRequest(displayName, email)).isEmpty())
            throw new IllegalArgumentException("用户资料参数不合法");
        return Map.of("targetUserId", userId, "displayName", displayName, "email", email);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String userId = (String) parameters.get("targetUserId");
        var current = repository
                .findView(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "用户不存在", "api.user.notFound"));
        String email = (String) parameters.get("email");
        if (Objects.equals(current.displayName(), parameters.get("displayName"))
                && Objects.equals(empty(current.email()), email))
            throw new ApiException(HttpStatus.BAD_REQUEST, "用户资料没有变化", "api.common.badRequest");
        return Map.of(
                "targetUserId", userId,
                "username", current.username(),
                "currentDisplayName", current.displayName(),
                "currentEmail", empty(current.email()),
                "currentStatus", current.status(),
                "displayName", (String) parameters.get("displayName"),
                "email", email);
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
                || FIELDS.stream().anyMatch(field -> !Objects.equals(normalized.get(field), previewFields.get(field))))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String userId = (String) normalized.get("targetUserId");
        service.updateProfileForAgent(
                userId,
                new UserUpdateRequest((String) normalized.get("displayName"), (String) normalized.get("email")),
                new UserProfileExpectation(
                        previewFields.get("username"),
                        previewFields.get("currentDisplayName"),
                        nullIfEmpty(previewFields.get("currentEmail")),
                        previewFields.get("currentStatus")),
                actor,
                metadata);
        return new LocalAgentWriteResult(userId, null);
    }

    private static String text(Object raw, int max) {
        if (!(raw instanceof String text) || text.length() > max) throw new IllegalArgumentException("用户资料参数不合法");
        return text.trim();
    }

    private static String empty(String value) {
        return value == null ? "" : value;
    }

    private static String nullIfEmpty(String value) {
        return value == null || value.isEmpty() ? null : value;
    }
}
