package com.kaiwu.module.project.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.service.ProjectService.ProjectRenameExpectation;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.starter.KaiwuContext;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Renames one project while leaving its stable code and service settings unchanged. */
@Component
public final class ProjectRenameAgentWriteHandler implements LocalAgentWriteHandler {
    private final ProjectService service;

    public ProjectRenameAgentWriteHandler(ProjectService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.PROJECT_RENAME;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("projectId", "projectName").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("项目参数不合法");
        if (!(parameters.get("projectId") instanceof String id) || !id.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("项目 ID 不合法");
        try {
            Long.parseLong(id);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("项目 ID 不合法", invalid);
        }
        if (!(parameters.get("projectName") instanceof String raw)) throw new IllegalArgumentException("项目名称不合法");
        String name = raw.trim();
        if (name.isEmpty() || name.length() > 100) throw new IllegalArgumentException("项目名称不合法");
        return Map.of("projectId", id, "projectName", name);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String id = (String) parameters.get("projectId");
        var project = service.project(id);
        if (project.projectName().equals(parameters.get("projectName")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目名称没有变化", "api.common.badRequest");
        return Map.of(
                "projectId", id,
                "projectCode", project.projectCode(),
                "currentName", project.projectName(),
                "projectName", (String) parameters.get("projectName"),
                "status", project.status());
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
                        .containsAll(Set.of("projectId", "projectCode", "currentName", "projectName", "status"))
                || !parameters.get("projectId").equals(previewFields.get("projectId"))
                || !parameters.get("projectName").equals(previewFields.get("projectName")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String id = (String) parameters.get("projectId");
        service.renameProjectForAgent(
                id,
                (String) parameters.get("projectName"),
                new ProjectRenameExpectation(
                        previewFields.get("projectCode"),
                        previewFields.get("currentName"),
                        previewFields.get("status")),
                actor,
                metadata);
        return new LocalAgentWriteResult(id, null);
    }
}
