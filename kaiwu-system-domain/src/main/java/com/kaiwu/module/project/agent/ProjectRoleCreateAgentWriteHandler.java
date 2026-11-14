package com.kaiwu.module.project.agent;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.dto.ProjectRoleCreateRequest;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.starter.KaiwuContext;
import jakarta.validation.Validator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Component;

/** Creates a project role through the same service and validation used by the management page. */
@Component
public final class ProjectRoleCreateAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> FIELDS = Set.of("projectId", "newRoleCode", "roleName", "description");
    private final ProjectService service;
    private final Validator validator;

    public ProjectRoleCreateAgentWriteHandler(ProjectService service, Validator validator) {
        this.service = service;
        this.validator = validator;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.PROJECT_ROLE_CREATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!FIELDS.containsAll(parameters.keySet())) throw new IllegalArgumentException("项目角色参数不合法");
        if (!(parameters.get("projectId") instanceof String projectId) || !projectId.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("项目 ID 不合法");
        try {
            Long.parseLong(projectId);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("项目 ID 不合法", invalid);
        }
        if (!(parameters.get("newRoleCode") instanceof String rawCode)
                || !(parameters.get("roleName") instanceof String rawName))
            throw new IllegalArgumentException("角色编码和名称不能为空");
        String code = rawCode.trim();
        String name = rawName.trim();
        String description = optional(parameters.get("description"));
        var request = new ProjectRoleCreateRequest(code, name, description);
        if (!validator.validate(request).isEmpty()) throw new IllegalArgumentException("项目角色参数不合法");
        Map<String, Object> normalized = new LinkedHashMap<>();
        normalized.put("projectId", projectId);
        normalized.put("newRoleCode", code);
        normalized.put("roleName", name);
        if (description != null) normalized.put("description", description);
        return normalized;
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String id = (String) parameters.get("projectId");
        var project = service.project(id);
        return Map.of(
                "projectId",
                id,
                "projectCode",
                project.projectCode(),
                "projectName",
                project.projectName(),
                "roleCode",
                (String) parameters.get("newRoleCode"),
                "roleName",
                (String) parameters.get("roleName"),
                "description",
                (String) parameters.getOrDefault("description", "-"));
    }

    @Override
    public String execute(Map<String, Object> parameters, KaiwuContext actor, RequestMetadata metadata) {
        return service.createRole(
                        (String) parameters.get("projectId"),
                        new ProjectRoleCreateRequest(
                                (String) parameters.get("newRoleCode"), (String) parameters.get("roleName"), (String)
                                        parameters.get("description")),
                        actor,
                        metadata)
                .id();
    }

    private static String optional(Object raw) {
        if (raw == null) return null;
        if (!(raw instanceof String text)) throw new IllegalArgumentException("角色描述类型不合法");
        String value = text.trim();
        if (value.length() > 255) throw new IllegalArgumentException("角色描述过长");
        return value.isEmpty() ? null : value;
    }
}
