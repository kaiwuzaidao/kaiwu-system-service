package com.kaiwu.module.project.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.service.ProjectService.ProjectRoleMenuExpectation;
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

/** Full role-menu replacement with a frozen preview and a per-project menu ownership check. */
@Component
public final class ProjectRoleMenuGrantAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> PREVIEW_FIELDS = Set.of(
            "projectId", "targetRoleId", "roleCode", "roleName", "description", "status", "currentMenuIds", "menuIds");
    private final ProjectService service;

    public ProjectRoleMenuGrantAgentWriteHandler(ProjectService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.PROJECT_ROLE_MENU_GRANT;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("projectId", "targetRoleId", "menuIds").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("角色菜单参数不合法");
        if (!(parameters.get("menuIds") instanceof List<?> raw) || raw.size() > 100)
            throw new IllegalArgumentException("菜单编号列表不合法");
        List<String> ids = new ArrayList<>(raw.size());
        for (Object item : raw) ids.add(id(item));
        if (Set.copyOf(ids).size() != ids.size()) throw new IllegalArgumentException("菜单编号不能重复");
        return Map.of(
                "projectId", id(parameters.get("projectId")),
                "targetRoleId", id(parameters.get("targetRoleId")),
                "menuIds", List.copyOf(ids));
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String projectId = (String) parameters.get("projectId");
        String roleId = (String) parameters.get("targetRoleId");
        Set<String> menuIds = Set.copyOf(menuIds(parameters));
        var role = service.previewRoleMenuGrant(projectId, roleId, menuIds);
        return Map.of(
                "projectId", projectId,
                "targetRoleId", roleId,
                "roleCode", role.roleCode(),
                "roleName", role.roleName(),
                "description", role.description() == null ? "" : role.description(),
                "status", role.status(),
                "currentMenuIds", joined(role.menuIds()),
                "menuIds", joined(menuIds));
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "重设角色菜单 " + previewFields.get("targetRoleId") + " " + previewFields.get("roleCode");
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
                || !Objects.equals(normalized.get("targetRoleId"), previewFields.get("targetRoleId"))
                || !joined(Set.copyOf(menuIds(normalized))).equals(previewFields.get("menuIds")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String roleId = (String) normalized.get("targetRoleId");
        service.grantRoleMenusForAgent(
                (String) normalized.get("projectId"),
                roleId,
                Set.copyOf(menuIds(normalized)),
                new ProjectRoleMenuExpectation(
                        previewFields.get("roleCode"),
                        previewFields.get("roleName"),
                        previewFields.get("description").isEmpty() ? null : previewFields.get("description"),
                        previewFields.get("status"),
                        parsed(previewFields.get("currentMenuIds"))),
                actor,
                metadata);
        return new LocalAgentWriteResult(roleId, null);
    }

    private static String id(Object raw) {
        if (!(raw instanceof String id) || !id.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("菜单或角色编号不合法");
        try {
            Long.parseLong(id);
            return id;
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("菜单或角色编号不合法", invalid);
        }
    }

    @SuppressWarnings("unchecked")
    private static List<String> menuIds(Map<String, Object> parameters) {
        return (List<String>) parameters.get("menuIds");
    }

    private static String joined(Set<String> ids) {
        return String.join(",", ids.stream().sorted().toList());
    }

    private static Set<String> parsed(String ids) {
        if (ids == null || ids.isEmpty()) return Set.of();
        var parsed = Arrays.asList(ids.split(",", -1));
        parsed.forEach(ProjectRoleMenuGrantAgentWriteHandler::id);
        return Set.copyOf(parsed);
    }
}
