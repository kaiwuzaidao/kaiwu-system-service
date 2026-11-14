package com.kaiwu.module.project.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.dto.ProjectMemberRequest;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.service.ProjectService.ProjectMemberExpectation;
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

/** Adds a project member or replaces their roles and status after a frozen preview. */
@Component
public final class ProjectMemberSaveAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> PREVIEW_FIELDS = Set.of(
            "projectId", "targetUserId", "existed", "username", "currentStatus", "currentRoleIds", "status", "roleIds");
    private final ProjectService service;

    public ProjectMemberSaveAgentWriteHandler(ProjectService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.PROJECT_MEMBER_SAVE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("projectId", "targetUserId", "status", "roleIds").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("项目成员参数不合法");
        String status = parameters.get("status") instanceof String value ? value : "";
        if (!Set.of("ACTIVE", "DISABLED").contains(status)) throw new IllegalArgumentException("成员状态不合法");
        if (!(parameters.get("roleIds") instanceof List<?> raw) || raw.isEmpty() || raw.size() > 100)
            throw new IllegalArgumentException("角色编号列表不合法");
        List<String> ids = new ArrayList<>(raw.size());
        for (Object item : raw) ids.add(id(item));
        if (Set.copyOf(ids).size() != ids.size()) throw new IllegalArgumentException("角色编号不能重复");
        return Map.of(
                "projectId", id(parameters.get("projectId")),
                "targetUserId", id(parameters.get("targetUserId")),
                "status", status,
                "roleIds", List.copyOf(ids));
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String projectId = (String) parameters.get("projectId");
        String userId = (String) parameters.get("targetUserId");
        String status = (String) parameters.get("status");
        Set<String> roles = Set.copyOf(roleIds(parameters));
        var current = service.previewMemberSave(projectId, userId, new ProjectMemberRequest(roles, status));
        return Map.of(
                "projectId", projectId,
                "targetUserId", userId,
                "existed", Boolean.toString(current.isPresent()),
                "username", current.map(m -> m.username()).orElse(""),
                "currentStatus", current.map(m -> m.status()).orElse(""),
                "currentRoleIds", current.map(m -> joined(m.roleIds())).orElse(""),
                "status", status,
                "roleIds", joined(roles));
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "设置项目成员 " + previewFields.get("targetUserId");
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
                || !Objects.equals(normalized.get("projectId"), previewFields.get("projectId"))
                || !Objects.equals(normalized.get("targetUserId"), previewFields.get("targetUserId"))
                || !Objects.equals(normalized.get("status"), previewFields.get("status"))
                || !joined(Set.copyOf(roleIds(normalized))).equals(previewFields.get("roleIds")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String projectId = (String) normalized.get("projectId");
        String userId = (String) normalized.get("targetUserId");
        service.saveMemberForAgent(
                projectId,
                userId,
                new ProjectMemberRequest(Set.copyOf(roleIds(normalized)), (String) normalized.get("status")),
                new ProjectMemberExpectation(
                        Boolean.parseBoolean(previewFields.get("existed")),
                        previewFields.get("username"),
                        previewFields.get("currentStatus"),
                        parsed(previewFields.get("currentRoleIds"))),
                actor,
                metadata);
        return new LocalAgentWriteResult(userId, null);
    }

    static String id(Object raw) {
        if (!(raw instanceof String id) || !id.matches("[1-9][0-9]{0,18}")) throw new IllegalArgumentException("编号不合法");
        try {
            Long.parseLong(id);
            return id;
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("编号不合法", invalid);
        }
    }

    @SuppressWarnings("unchecked")
    private static List<String> roleIds(Map<String, Object> parameters) {
        return (List<String>) parameters.get("roleIds");
    }

    static String joined(Set<String> ids) {
        return String.join(",", ids.stream().sorted().toList());
    }

    static Set<String> parsed(String ids) {
        if (ids == null || ids.isEmpty()) return Set.of();
        var parsed = Arrays.asList(ids.split(",", -1));
        parsed.forEach(ProjectMemberSaveAgentWriteHandler::id);
        return Set.copyOf(parsed);
    }
}
