package com.kaiwu.module.identity.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.service.OrgService;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Replaces a user's ordered department assignments after a frozen preview. */
@Component
public final class UserDepartmentAssignAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> PREVIEW_FIELDS = Set.of("targetUserId", "currentDepartmentIds", "departmentIds");
    private final OrgService service;

    public UserDepartmentAssignAgentWriteHandler(OrgService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.USER_DEPARTMENT_ASSIGN;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("targetUserId", "departmentIds").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("用户部门参数不合法");
        if (!(parameters.get("departmentIds") instanceof List<?> raw) || raw.size() > 20)
            throw new IllegalArgumentException("部门编号列表不合法");
        List<String> ids = new ArrayList<>(raw.size());
        for (Object item : raw) ids.add(id(item));
        if (Set.copyOf(ids).size() != ids.size()) throw new IllegalArgumentException("部门编号不能重复");
        return Map.of("targetUserId", id(parameters.get("targetUserId")), "departmentIds", List.copyOf(ids));
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String userId = (String) parameters.get("targetUserId");
        List<String> proposed = departmentIds(parameters);
        List<String> current = service.previewUserDepartmentAssignment(userId, proposed);
        return Map.of(
                "targetUserId", userId,
                "currentDepartmentIds", String.join(",", current),
                "departmentIds", String.join(",", proposed));
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "设置用户部门 " + previewFields.get("targetUserId");
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
                || !String.join(",", departmentIds(normalized)).equals(previewFields.get("departmentIds")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String userId = (String) normalized.get("targetUserId");
        service.assignDepartmentsForAgent(
                userId, departmentIds(normalized), parsed(previewFields.get("currentDepartmentIds")), actor, metadata);
        return new LocalAgentWriteResult(userId, null);
    }

    private static String id(Object raw) {
        if (!(raw instanceof String id) || !id.matches("[1-9][0-9]{0,18}")) throw new IllegalArgumentException("编号不合法");
        try {
            Long.parseLong(id);
            return id;
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("编号不合法", invalid);
        }
    }

    @SuppressWarnings("unchecked")
    private static List<String> departmentIds(Map<String, Object> parameters) {
        return (List<String>) parameters.get("departmentIds");
    }

    private static List<String> parsed(String ids) {
        if (ids == null || ids.isEmpty()) return List.of();
        List<String> parsed = Arrays.asList(ids.split(",", -1));
        parsed.forEach(UserDepartmentAssignAgentWriteHandler::id);
        if (Set.copyOf(parsed).size() != parsed.size())
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        return List.copyOf(parsed);
    }
}
