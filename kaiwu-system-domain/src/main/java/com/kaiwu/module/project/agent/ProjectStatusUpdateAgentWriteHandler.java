package com.kaiwu.module.project.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.service.ProjectService.ProjectStatusExpectation;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Changes a project's status after a frozen preview, live authorization, and locked state comparison. */
@Component
public final class ProjectStatusUpdateAgentWriteHandler implements LocalAgentWriteHandler {
    private final ProjectService service;

    public ProjectStatusUpdateAgentWriteHandler(ProjectService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.PROJECT_STATUS_UPDATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("projectId", "status").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("项目状态参数不合法");
        if (!(parameters.get("projectId") instanceof String id) || !id.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("项目 ID 不合法");
        try {
            Long.parseLong(id);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("项目 ID 不合法", invalid);
        }
        if (!(parameters.get("status") instanceof String status)
                || !Set.of("ACTIVE", "DISABLED", "ARCHIVED").contains(status))
            throw new IllegalArgumentException("目标状态不合法");
        return Map.of("projectId", id, "status", status);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String id = (String) parameters.get("projectId");
        var project = service.project(id);
        if (project.builtIn())
            throw new ApiException(HttpStatus.BAD_REQUEST, "内置 system 项目不可停用或归档", "api.common.badRequest");
        if (project.status().equals(parameters.get("status")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目状态没有变化", "api.common.badRequest");
        return Map.of(
                "projectId", id,
                "projectCode", project.projectCode(),
                "projectName", project.projectName(),
                "currentStatus", project.status(),
                "status", (String) parameters.get("status"));
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return "ACTIVE".equals(parameters.get("status")) ? ConfirmationMode.REQUIRED : ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return switch ((String) parameters.get("status")) {
            case "DISABLED" -> "停用项目 " + previewFields.get("projectCode");
            case "ARCHIVED" -> "归档项目 " + previewFields.get("projectCode");
            default -> null;
        };
    }

    @Override
    public LocalAgentWriteResult executeForAction(
            Map<String, Object> parameters,
            Map<String, String> previewFields,
            KaiwuContext actor,
            RequestMetadata metadata) {
        if (previewFields == null
                || !previewFields
                        .keySet()
                        .containsAll(Set.of("projectId", "projectCode", "projectName", "currentStatus", "status"))
                || !parameters.get("projectId").equals(previewFields.get("projectId"))
                || !parameters.get("status").equals(previewFields.get("status")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String id = (String) parameters.get("projectId");
        service.updateStatusForAgent(
                id,
                (String) parameters.get("status"),
                new ProjectStatusExpectation(
                        previewFields.get("projectCode"),
                        previewFields.get("projectName"),
                        previewFields.get("currentStatus")),
                actor,
                metadata);
        return new LocalAgentWriteResult(id, null);
    }
}
