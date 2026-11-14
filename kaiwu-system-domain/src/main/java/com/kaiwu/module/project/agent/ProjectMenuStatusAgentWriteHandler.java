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

/** Status changes use the same service and audit path as the management UI. */
@Component
public final class ProjectMenuStatusAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> PREVIEW_FIELDS = Set.of(
            "projectId",
            "targetMenuId",
            "menuName",
            "menuType",
            "parentId",
            "permissionCode",
            "currentStatus",
            "status");
    private final ProjectService service;

    public ProjectMenuStatusAgentWriteHandler(ProjectService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.PROJECT_MENU_STATUS_UPDATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("projectId", "targetMenuId", "status").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("项目菜单状态参数不合法");
        Object status = parameters.get("status");
        if (!(status instanceof String value) || !Set.of("ACTIVE", "DISABLED").contains(value))
            throw new IllegalArgumentException("菜单状态不合法");
        return Map.of(
                "projectId", ProjectMenuWriteIds.id(parameters.get("projectId")),
                "targetMenuId", ProjectMenuWriteIds.id(parameters.get("targetMenuId")),
                "status", value);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String projectId = (String) parameters.get("projectId");
        String menuId = (String) parameters.get("targetMenuId");
        ProjectMenuView menu = service.menuForAgent(projectId, menuId);
        String status = (String) parameters.get("status");
        if (status.equals(menu.status()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目菜单状态没有变化", "api.common.badRequest");
        return Map.of(
                "projectId", projectId,
                "targetMenuId", menuId,
                "menuName", menu.menuName(),
                "menuType", menu.menuType(),
                "parentId", ProjectMenuWriteIds.empty(menu.parentId()),
                "permissionCode", ProjectMenuWriteIds.empty(menu.permissionCode()),
                "currentStatus", menu.status(),
                "status", status);
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return "DISABLED".equals(parameters.get("status")) ? ConfirmationMode.STRONG : ConfirmationMode.REQUIRED;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "DISABLED".equals(parameters.get("status"))
                ? "停用菜单 " + previewFields.get("targetMenuId") + " " + previewFields.get("menuName")
                : null;
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
                || !Objects.equals(parameters.get("targetMenuId"), previewFields.get("targetMenuId"))
                || !Objects.equals(parameters.get("status"), previewFields.get("status")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String menuId = (String) parameters.get("targetMenuId");
        service.updateMenuStatusForAgent(
                (String) parameters.get("projectId"),
                menuId,
                (String) parameters.get("status"),
                new ProjectMenuEditExpectation(
                        ProjectMenuWriteIds.nullIfEmpty(previewFields.get("parentId")),
                        previewFields.get("menuName"),
                        previewFields.get("menuType"),
                        ProjectMenuWriteIds.nullIfEmpty(previewFields.get("permissionCode")),
                        previewFields.get("currentStatus")),
                actor,
                metadata);
        return new LocalAgentWriteResult(menuId, null);
    }
}
