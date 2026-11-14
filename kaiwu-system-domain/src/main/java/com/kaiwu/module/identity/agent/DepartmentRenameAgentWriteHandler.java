package com.kaiwu.module.identity.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.service.OrgService;
import com.kaiwu.module.identity.service.OrgService.DepartmentRenameExpectation;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.starter.KaiwuContext;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Renames a department without changing its code, tree position or status. */
@Component
public final class DepartmentRenameAgentWriteHandler implements LocalAgentWriteHandler {
    private final OrgService service;

    public DepartmentRenameAgentWriteHandler(OrgService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.DEPARTMENT_RENAME;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("departmentId", "departmentName").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("部门参数不合法");
        if (!(parameters.get("departmentId") instanceof String id) || !id.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("部门 ID 不合法");
        try {
            Long.parseLong(id);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("部门 ID 不合法", invalid);
        }
        if (!(parameters.get("departmentName") instanceof String raw)) throw new IllegalArgumentException("部门名称不合法");
        String name = raw.trim();
        if (name.isEmpty() || name.length() > 100) throw new IllegalArgumentException("部门名称不合法");
        return Map.of("departmentId", id, "departmentName", name);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String id = (String) parameters.get("departmentId");
        var current = service.department(id);
        if (current.name().equals(parameters.get("departmentName")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "部门名称没有变化", "api.common.badRequest");
        return Map.of(
                "departmentId",
                id,
                "currentName",
                current.name(),
                "departmentName",
                (String) parameters.get("departmentName"),
                "departmentCode",
                current.code(),
                "parentDepartmentId",
                current.parentId() == null ? "" : current.parentId(),
                "status",
                current.status());
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
                        .containsAll(Set.of(
                                "departmentId",
                                "currentName",
                                "departmentName",
                                "departmentCode",
                                "parentDepartmentId",
                                "status"))
                || !parameters.get("departmentId").equals(previewFields.get("departmentId"))
                || !parameters.get("departmentName").equals(previewFields.get("departmentName")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String id = (String) parameters.get("departmentId");
        var expected = new DepartmentRenameExpectation(
                previewFields.get("currentName"), previewFields.get("departmentCode"),
                previewFields.get("parentDepartmentId"), previewFields.get("status"));
        service.renameDepartment(id, (String) parameters.get("departmentName"), expected, actor, metadata);
        return new LocalAgentWriteResult(id, null);
    }
}
