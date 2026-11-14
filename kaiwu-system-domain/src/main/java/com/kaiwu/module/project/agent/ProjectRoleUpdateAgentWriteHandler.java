package com.kaiwu.module.project.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.dto.ProjectRoleUpdateRequest;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.service.ProjectService.ProjectRoleEditExpectation;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.starter.KaiwuContext;
import jakarta.validation.Validator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Edits a mutable project role after checking the frozen preview against a locked current row. */
@Component
public final class ProjectRoleUpdateAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> FIELDS = Set.of("projectId", "targetRoleId", "roleName", "description");
    private static final Set<String> PREVIEW_FIELDS = Set.of(
            "projectId",
            "targetRoleId",
            "roleCode",
            "currentName",
            "roleName",
            "currentDescription",
            "description",
            "status");
    private final ProjectService service;
    private final Validator validator;

    public ProjectRoleUpdateAgentWriteHandler(ProjectService service, Validator validator) {
        this.service = service;
        this.validator = validator;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.PROJECT_ROLE_UPDATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!FIELDS.containsAll(parameters.keySet())) throw new IllegalArgumentException("项目角色参数不合法");
        String projectId = id(parameters.get("projectId"));
        String roleId = id(parameters.get("targetRoleId"));
        if (!parameters.containsKey("roleName") && !parameters.containsKey("description"))
            throw new IllegalArgumentException("请填写要修改的角色名称或描述");
        Map<String, Object> normalized = new LinkedHashMap<>();
        normalized.put("projectId", projectId);
        normalized.put("targetRoleId", roleId);
        if (parameters.containsKey("roleName")) {
            if (!(parameters.get("roleName") instanceof String raw)) throw new IllegalArgumentException("角色名称不合法");
            String name = raw.trim();
            if (name.isEmpty() || name.length() > 100) throw new IllegalArgumentException("角色名称不合法");
            normalized.put("roleName", name);
        }
        if (parameters.containsKey("description")) {
            if (!(parameters.get("description") instanceof String raw)) throw new IllegalArgumentException("角色描述不合法");
            String description = raw.trim();
            if (description.length() > 255) throw new IllegalArgumentException("角色描述过长");
            normalized.put("description", description);
        }
        return normalized;
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String projectId = (String) parameters.get("projectId");
        String roleId = (String) parameters.get("targetRoleId");
        var role = service.editableRole(projectId, roleId);
        String targetName = (String) parameters.getOrDefault("roleName", role.roleName());
        String targetDescription = (String) parameters.getOrDefault("description", empty(role.description()));
        if (Objects.equals(targetName, role.roleName()) && Objects.equals(targetDescription, empty(role.description())))
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目角色没有变化", "api.common.badRequest");
        var request = new ProjectRoleUpdateRequest(targetName, targetDescription.isEmpty() ? null : targetDescription);
        if (!validator.validate(request).isEmpty()) throw new IllegalArgumentException("项目角色参数不合法");
        return Map.of(
                "projectId",
                projectId,
                "targetRoleId",
                roleId,
                "roleCode",
                role.roleCode(),
                "currentName",
                role.roleName(),
                "roleName",
                targetName,
                "currentDescription",
                empty(role.description()),
                "description",
                targetDescription,
                "status",
                role.status());
    }

    @Override
    public LocalAgentWriteResult executeForAction(
            Map<String, Object> parameters,
            Map<String, String> previewFields,
            KaiwuContext actor,
            RequestMetadata metadata) {
        if (previewFields == null
                || !previewFields.keySet().equals(PREVIEW_FIELDS)
                || !Objects.equals(parameters.get("projectId"), previewFields.get("projectId"))
                || !Objects.equals(parameters.get("targetRoleId"), previewFields.get("targetRoleId"))
                || (parameters.containsKey("roleName")
                        && !Objects.equals(parameters.get("roleName"), previewFields.get("roleName")))
                || (parameters.containsKey("description")
                        && !Objects.equals(parameters.get("description"), previewFields.get("description"))))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        var request = new ProjectRoleUpdateRequest(
                previewFields.get("roleName"), emptyToNull(previewFields.get("description")));
        if (!validator.validate(request).isEmpty())
            throw new ApiException(HttpStatus.BAD_REQUEST, "操作参数不完整或格式错误", "api.agent.actionParameters");
        service.updateRoleForAgent(
                (String) parameters.get("projectId"),
                (String) parameters.get("targetRoleId"),
                request,
                new ProjectRoleEditExpectation(
                        previewFields.get("roleCode"),
                        previewFields.get("currentName"),
                        emptyToNull(previewFields.get("currentDescription")),
                        previewFields.get("status")),
                actor,
                metadata);
        return new LocalAgentWriteResult((String) parameters.get("targetRoleId"), null);
    }

    private static String id(Object raw) {
        if (!(raw instanceof String id) || !id.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("项目角色编号不合法");
        try {
            Long.parseLong(id);
            return id;
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("项目角色编号不合法", invalid);
        }
    }

    private static String empty(String value) {
        return value == null ? "" : value;
    }

    private static String emptyToNull(String value) {
        return value == null || value.isEmpty() ? null : value;
    }
}
