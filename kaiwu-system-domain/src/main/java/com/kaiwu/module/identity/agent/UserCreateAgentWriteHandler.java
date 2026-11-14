package com.kaiwu.module.identity.agent;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.service.UserService;
import com.kaiwu.module.user.dto.UserCreateRequest;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.starter.KaiwuContext;
import jakarta.validation.Validator;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Component;

/** Creates a user with a server-generated one-time initial password that is never stored in Agent state. */
@Component
public final class UserCreateAgentWriteHandler implements LocalAgentWriteHandler {
    private static final SecureRandom RANDOM = new SecureRandom();

    private final UserService service;
    private final Validator validator;

    public UserCreateAgentWriteHandler(UserService service, Validator validator) {
        this.service = service;
        this.validator = validator;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.USER_CREATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("username", "displayName", "email").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("用户参数不合法");
        String username = required(parameters, "username", 64);
        String displayName = required(parameters, "displayName", 100);
        String email = optional(parameters, "email", 200);
        // Reuse the same DTO constraints as UserController; no secret enters normalized parameters.
        if (!validator
                .validate(new UserCreateRequest(username, displayName, email, "validation-only-password"))
                .isEmpty()) throw new IllegalArgumentException("用户参数不合法");
        Map<String, Object> normalized = new LinkedHashMap<>();
        normalized.put("username", username);
        normalized.put("displayName", displayName);
        if (email != null) normalized.put("email", email);
        return normalized;
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        return Map.of(
                "username", (String) parameters.get("username"),
                "displayName", (String) parameters.get("displayName"),
                "email", (String) parameters.getOrDefault("email", "-"));
    }

    @Override
    public LocalAgentWriteResult executeForAction(
            Map<String, Object> parameters, KaiwuContext actor, RequestMetadata metadata) {
        byte[] random = new byte[24];
        RANDOM.nextBytes(random);
        String initialPassword = Base64.getUrlEncoder().withoutPadding().encodeToString(random);
        var created = service.create(
                new UserCreateRequest(
                        (String) parameters.get("username"),
                        (String) parameters.get("displayName"),
                        (String) parameters.get("email"),
                        initialPassword),
                actor,
                metadata);
        return new LocalAgentWriteResult(created.id(), initialPassword);
    }

    private static String required(Map<String, Object> values, String key, int max) {
        String value = optional(values, key, max);
        if (value == null) throw new IllegalArgumentException("缺少用户必填信息");
        return value;
    }

    private static String optional(Map<String, Object> values, String key, int max) {
        Object raw = values.get(key);
        if (raw == null) return null;
        if (!(raw instanceof String text)) throw new IllegalArgumentException("用户参数类型不合法");
        String value = text.trim();
        if (value.length() > max) throw new IllegalArgumentException("用户参数过长");
        return value.isEmpty() ? null : value;
    }
}
