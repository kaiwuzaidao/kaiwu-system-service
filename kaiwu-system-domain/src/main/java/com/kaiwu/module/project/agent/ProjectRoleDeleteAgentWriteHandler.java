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

/** Deletes an unassigned custom role through the management service after strong confirmation. */
@Component
public final class ProjectRoleDeleteAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> PREVIEW_FIELDS =
            Set.of("projectId", "targetRoleId", "roleCode", "roleName", "description", "status");
    private final ProjectService service;

    public ProjectRoleDeleteAgentWriteHandler(ProjectService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.PROJECT_ROLE_DELETE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("projectId", "targetRoleId").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("项目角色参数不合法");
        return Map.of("projectId", id(parameters.get("projectId")), "targetRoleId", id(parameters.get("targetRoleId")));
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String projectId = (String) parameters.get("projectId");
        String roleId = (String) parameters.get("targetRoleId");
        var role = service.previewRoleDeletion(projectId, roleId);
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
                "status",
                role.status());
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "删除角色 " + previewFields.get("targetRoleId") + " " + previewFields.get("roleCode");
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
                || !Objects.equals(parameters.get("targetRoleId"), previewFields.get("targetRoleId")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String roleId = (String) parameters.get("targetRoleId");
        service.deleteRoleForAgent(
                (String) parameters.get("projectId"),
                roleId,
                new ProjectRoleEditExpectation(
                        previewFields.get("roleCode"),
                        previewFields.get("roleName"),
                        previewFields.get("description").isEmpty() ? null : previewFields.get("description"),
                        previewFields.get("status")),
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
