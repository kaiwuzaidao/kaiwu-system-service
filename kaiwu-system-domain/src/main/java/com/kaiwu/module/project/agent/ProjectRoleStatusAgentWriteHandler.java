package com.kaiwu.module.project.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.service.ProjectService.ProjectRoleEditExpectation;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Changes a custom role's status, requiring a typed phrase before permission removal. */
@Component
public final class ProjectRoleStatusAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> PREVIEW_FIELDS =
            Set.of("projectId", "targetRoleId", "roleCode", "roleName", "description", "currentStatus", "status");
    private final ProjectService service;

    public ProjectRoleStatusAgentWriteHandler(ProjectService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.PROJECT_ROLE_STATUS_UPDATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("projectId", "targetRoleId", "status").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("项目角色状态参数不合法");
        String projectId = id(parameters.get("projectId"));
        String roleId = id(parameters.get("targetRoleId"));
        if (!(parameters.get("status") instanceof String status)
                || !Set.of("ACTIVE", "DISABLED").contains(status)) throw new IllegalArgumentException("目标状态不合法");
        return Map.of("projectId", projectId, "targetRoleId", roleId, "status", status);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String projectId = (String) parameters.get("projectId");
        String roleId = (String) parameters.get("targetRoleId");
        var role = service.editableRole(projectId, roleId);
        String status = (String) parameters.get("status");
        if (status.equals(role.status()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目角色状态没有变化", "api.common.badRequest");
        return Map.of(
                "projectId",
                projectId,
                "targetRoleId",
                roleId,
                "roleCode",
                role.roleCode(),
                "roleName",
                role.roleName(),
                "description",
                role.description() == null ? "" : role.description(),
                "currentStatus",
                role.status(),
                "status",
                status);
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return "DISABLED".equals(parameters.get("status")) ? ConfirmationMode.STRONG : ConfirmationMode.REQUIRED;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "DISABLED".equals(parameters.get("status")) ? "停用角色 " + previewFields.get("roleCode") : null;
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
                || !Objects.equals(parameters.get("status"), previewFields.get("status")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String roleId = (String) parameters.get("targetRoleId");
        service.updateRoleStatusForAgent(
                (String) parameters.get("projectId"),
                roleId,
                (String) parameters.get("status"),
                new ProjectRoleEditExpectation(
                        previewFields.get("roleCode"),
                        previewFields.get("roleName"),
                        previewFields.get("description").isEmpty() ? null : previewFields.get("description"),
                        previewFields.get("currentStatus")),
                actor,
                metadata);
        return new LocalAgentWriteResult(roleId, null);
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
}
