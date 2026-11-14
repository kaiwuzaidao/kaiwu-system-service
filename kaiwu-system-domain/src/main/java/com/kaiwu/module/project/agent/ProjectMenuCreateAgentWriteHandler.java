package com.kaiwu.module.project.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.service.ProjectService.ProjectRenameExpectation;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import jakarta.validation.Validator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Creates a project menu after validating the full menu form and freezing the project target. */
@Component
public final class ProjectMenuCreateAgentWriteHandler implements LocalAgentWriteHandler {
    static final Set<String> INPUT_FIELDS = Set.of(
            "parentId",
            "menuName",
            "menuNameKey",
            "menuType",
            "routePath",
            "componentPath",
            "permissionCode",
            "icon",
            "sortNo",
            "visible");
    private static final Set<String> PREVIEW_FIELDS = Set.of(
            "projectId",
            "projectCode",
            "projectName",
            "projectStatus",
            "parentId",
            "menuName",
            "menuNameKey",
            "menuType",
            "routePath",
            "componentPath",
            "permissionCode",
            "icon",
            "sortNo",
            "visible");
    private final ProjectService service;
    private final Validator validator;

    public ProjectMenuCreateAgentWriteHandler(ProjectService service, Validator validator) {
        this.service = service;
        this.validator = validator;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.PROJECT_MENU_CREATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        return ProjectMenuAgentInput.normalize(parameters, false, validator);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String projectId = (String) parameters.get("projectId");
        var project = service.previewMenuCreation(projectId, ProjectMenuAgentInput.request(parameters));
        Map<String, String> preview = new LinkedHashMap<>();
        preview.put("projectId", projectId);
        preview.put("projectCode", project.projectCode());
        preview.put("projectName", project.projectName());
        preview.put("projectStatus", project.status());
        INPUT_FIELDS.forEach(field -> preview.put(field, ProjectMenuAgentInput.text(parameters, field)));
        return Map.copyOf(preview);
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "创建项目菜单 " + previewFields.get("menuName");
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
                || INPUT_FIELDS.stream().anyMatch(field -> !ProjectMenuAgentInput.text(normalized, field)
                        .equals(previewFields.get(field))))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String projectId = (String) normalized.get("projectId");
        var created = service.createMenuForAgent(
                projectId,
                ProjectMenuAgentInput.request(normalized),
                new ProjectRenameExpectation(
                        previewFields.get("projectCode"),
                        previewFields.get("projectName"),
                        previewFields.get("projectStatus")),
                actor,
                metadata);
        return new LocalAgentWriteResult(created.id(), null);
    }
}
