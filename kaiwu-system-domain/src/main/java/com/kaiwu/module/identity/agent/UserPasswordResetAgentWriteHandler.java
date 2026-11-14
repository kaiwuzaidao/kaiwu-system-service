package com.kaiwu.module.identity.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.repository.UserRepository;
import com.kaiwu.module.identity.service.UserService;
import com.kaiwu.module.identity.service.UserService.UserResetExpectation;
import com.kaiwu.module.user.dto.ResetPasswordRequest;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Generates a temporary password only after strong confirmation; the action store never receives it. */
@Component
public final class UserPasswordResetAgentWriteHandler implements LocalAgentWriteHandler {
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final Set<String> PREVIEW_FIELDS = Set.of("targetUserId", "username", "displayName", "status");
    private final UserRepository repository;
    private final UserService service;

    public UserPasswordResetAgentWriteHandler(UserRepository repository, UserService service) {
        this.repository = repository;
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.USER_PASSWORD_RESET;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("targetUserId").equals(parameters.keySet())) throw new IllegalArgumentException("目标用户参数不合法");
        Object raw = parameters.get("targetUserId");
        if (!(raw instanceof String userId) || !userId.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("用户 ID 不合法");
        try {
            Long.parseLong(userId);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("用户 ID 不合法", invalid);
        }
        return Map.of("targetUserId", userId);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String userId = (String) parameters.get("targetUserId");
        if (actor.userId().equals(userId))
            throw new ApiException(HttpStatus.BAD_REQUEST, "请通过个人安全设置修改自己的密码", "api.user.changeOwnPassword");
        var target = repository
                .findView(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "用户不存在", "api.user.notFound"));
        return Map.of(
                "targetUserId", userId,
                "username", target.username(),
                "displayName", target.displayName(),
                "status", target.status());
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "重置用户密码 " + previewFields.get("username");
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
                || !Objects.equals(normalized.get("targetUserId"), previewFields.get("targetUserId")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        byte[] random = new byte[24];
        RANDOM.nextBytes(random);
        String temporaryPassword = Base64.getUrlEncoder().withoutPadding().encodeToString(random);
        String userId = (String) normalized.get("targetUserId");
        service.resetPasswordForAgent(
                userId,
                new ResetPasswordRequest(temporaryPassword),
                new UserResetExpectation(
                        previewFields.get("username"), previewFields.get("displayName"), previewFields.get("status")),
                actor,
                metadata);
        return new LocalAgentWriteResult(userId, temporaryPassword);
    }
}
