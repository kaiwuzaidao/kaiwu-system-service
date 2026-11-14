package com.kaiwu.module.identity.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.service.OrgService;
import com.kaiwu.module.identity.service.OrgService.DepartmentRenameExpectation;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Updates a department's status with a frozen, locked comparison. */
@Component
public final class DepartmentStatusUpdateAgentWriteHandler implements LocalAgentWriteHandler {
    private final OrgService service;

    public DepartmentStatusUpdateAgentWriteHandler(OrgService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.DEPARTMENT_STATUS_UPDATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("departmentId", "status").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("部门状态参数不合法");
        if (!(parameters.get("departmentId") instanceof String id) || !id.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("部门 ID 不合法");
        try {
            Long.parseLong(id);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("部门 ID 不合法", invalid);
        }
        if (!(parameters.get("status") instanceof String status)
                || !Set.of("ENABLED", "DISABLED").contains(status)) throw new IllegalArgumentException("目标状态不合法");
        return Map.of("departmentId", id, "status", status);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String id = (String) parameters.get("departmentId");
        var current = service.department(id);
        if (current.status().equals(parameters.get("status")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "部门状态没有变化", "api.common.badRequest");
        return Map.of(
                "departmentId",
                id,
                "departmentName",
                current.name(),
                "departmentCode",
                current.code(),
                "parentDepartmentId",
                current.parentId() == null ? "" : current.parentId(),
                "currentStatus",
                current.status(),
                "status",
                (String) parameters.get("status"));
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return "DISABLED".equals(parameters.get("status")) ? ConfirmationMode.STRONG : ConfirmationMode.REQUIRED;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return confirmationMode(parameters) == ConfirmationMode.STRONG
                ? "停用部门 " + previewFields.get("departmentCode")
                : null;
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
                                "departmentName",
                                "departmentCode",
                                "parentDepartmentId",
                                "currentStatus",
                                "status"))
                || !parameters.get("departmentId").equals(previewFields.get("departmentId"))
                || !parameters.get("status").equals(previewFields.get("status")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String id = (String) parameters.get("departmentId");
        service.updateDepartmentStatus(
                id,
                (String) parameters.get("status"),
                new DepartmentRenameExpectation(
                        previewFields.get("departmentName"), previewFields.get("departmentCode"),
                        previewFields.get("parentDepartmentId"), previewFields.get("currentStatus")),
                actor,
                metadata);
        return new LocalAgentWriteResult(id, null);
    }
}
