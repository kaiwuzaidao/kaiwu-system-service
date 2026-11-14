package com.kaiwu.module.project.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.service.ProjectService.ProjectMenuFullExpectation;
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

/** Full menu edit with the original fields frozen in the confirmation preview. */
@Component
public final class ProjectMenuUpdateAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> PREVIEW_FIELDS = Set.of(
            "projectId",
            "targetMenuId",
            "currentParentId",
            "currentMenuName",
            "currentMenuNameKey",
            "currentMenuType",
            "currentRoutePath",
            "currentComponentPath",
            "currentPermissionCode",
            "currentIcon",
            "currentSortNo",
            "currentVisible",
            "currentStatus",
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

    public ProjectMenuUpdateAgentWriteHandler(ProjectService service, Validator validator) {
        this.service = service;
        this.validator = validator;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.PROJECT_MENU_UPDATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        return ProjectMenuAgentInput.normalize(parameters, true, validator);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String projectId = (String) parameters.get("projectId");
        String menuId = (String) parameters.get("targetMenuId");
        var current = service.previewMenuUpdate(projectId, menuId, ProjectMenuAgentInput.request(parameters));
        Map<String, String> preview = new LinkedHashMap<>();
        preview.put("projectId", projectId);
        preview.put("targetMenuId", menuId);
        preview.put("currentParentId", ProjectMenuWriteIds.empty(current.parentId()));
        preview.put("currentMenuName", current.menuName());
        preview.put("currentMenuNameKey", ProjectMenuWriteIds.empty(current.menuNameKey()));
        preview.put("currentMenuType", current.menuType());
        preview.put("currentRoutePath", ProjectMenuWriteIds.empty(current.routePath()));
        preview.put("currentComponentPath", ProjectMenuWriteIds.empty(current.componentPath()));
        preview.put("currentPermissionCode", ProjectMenuWriteIds.empty(current.permissionCode()));
        preview.put("currentIcon", ProjectMenuWriteIds.empty(current.icon()));
        preview.put("currentSortNo", Integer.toString(current.sortNo()));
        preview.put("currentVisible", Boolean.toString(current.visible()));
        preview.put("currentStatus", current.status());
        ProjectMenuCreateAgentWriteHandler.INPUT_FIELDS.forEach(
                field -> preview.put(field, ProjectMenuAgentInput.text(parameters, field)));
        return Map.copyOf(preview);
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "编辑项目菜单 " + previewFields.get("targetMenuId") + " " + previewFields.get("currentMenuName");
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
                || !Objects.equals(normalized.get("targetMenuId"), previewFields.get("targetMenuId"))
                || ProjectMenuCreateAgentWriteHandler.INPUT_FIELDS.stream()
                        .anyMatch(field ->
                                !ProjectMenuAgentInput.text(normalized, field).equals(previewFields.get(field))))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        ProjectMenuFullExpectation expected;
        try {
            expected = new ProjectMenuFullExpectation(
                    ProjectMenuWriteIds.nullIfEmpty(previewFields.get("currentParentId")),
                    previewFields.get("currentMenuName"),
                    ProjectMenuWriteIds.nullIfEmpty(previewFields.get("currentMenuNameKey")),
                    previewFields.get("currentMenuType"),
                    ProjectMenuWriteIds.nullIfEmpty(previewFields.get("currentRoutePath")),
                    ProjectMenuWriteIds.nullIfEmpty(previewFields.get("currentComponentPath")),
                    ProjectMenuWriteIds.nullIfEmpty(previewFields.get("currentPermissionCode")),
                    ProjectMenuWriteIds.nullIfEmpty(previewFields.get("currentIcon")),
                    Integer.parseInt(previewFields.get("currentSortNo")),
                    parseBoolean(previewFields.get("currentVisible")),
                    previewFields.get("currentStatus"));
        } catch (IllegalArgumentException invalid) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        }
        String menuId = (String) normalized.get("targetMenuId");
        var updated = service.updateMenuForAgent(
                (String) normalized.get("projectId"),
                menuId,
                ProjectMenuAgentInput.request(normalized),
                expected,
                actor,
                metadata);
        return new LocalAgentWriteResult(updated.id(), null);
    }

    private static boolean parseBoolean(String value) {
        if (!Set.of("true", "false").contains(value)) throw new IllegalArgumentException("显示状态不合法");
        return Boolean.parseBoolean(value);
    }
}
