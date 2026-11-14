package com.kaiwu.module.project.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.service.ProjectService.ProjectMenuEditExpectation;
import com.kaiwu.module.project.vo.ProjectMenuView;
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

/** Deletes a leaf project menu only after strong confirmation and a locked preview comparison. */
@Component
public final class ProjectMenuDeleteAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> PREVIEW_FIELDS =
            Set.of("projectId", "targetMenuId", "menuName", "menuType", "parentId", "permissionCode", "status");
    private final ProjectService service;

    public ProjectMenuDeleteAgentWriteHandler(ProjectService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.PROJECT_MENU_DELETE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("projectId", "targetMenuId").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("项目菜单参数不合法");
        return Map.of(
                "projectId", ProjectMenuWriteIds.id(parameters.get("projectId")),
                "targetMenuId", ProjectMenuWriteIds.id(parameters.get("targetMenuId")));
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String projectId = (String) parameters.get("projectId");
        String menuId = (String) parameters.get("targetMenuId");
        ProjectMenuView menu = service.previewMenuDeletion(projectId, menuId);
        return Map.of(
                "projectId", projectId,
                "targetMenuId", menuId,
                "menuName", menu.menuName(),
                "menuType", menu.menuType(),
                "parentId", ProjectMenuWriteIds.empty(menu.parentId()),
                "permissionCode", ProjectMenuWriteIds.empty(menu.permissionCode()),
                "status", menu.status());
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "删除菜单 " + previewFields.get("targetMenuId") + " " + previewFields.get("menuName");
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
                || !Objects.equals(parameters.get("targetMenuId"), previewFields.get("targetMenuId")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String menuId = (String) parameters.get("targetMenuId");
        service.deleteMenuForAgent(
                (String) parameters.get("projectId"),
                menuId,
                new ProjectMenuEditExpectation(
                        ProjectMenuWriteIds.nullIfEmpty(previewFields.get("parentId")),
                        previewFields.get("menuName"),
                        previewFields.get("menuType"),
                        ProjectMenuWriteIds.nullIfEmpty(previewFields.get("permissionCode")),
                        previewFields.get("status")),
                actor,
                metadata);
        return new LocalAgentWriteResult(menuId, null);
    }
}
