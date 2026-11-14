package com.kaiwu.module.identity.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.service.OrgService;
import com.kaiwu.module.identity.service.OrgService.DepartmentDeleteExpectation;
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

/** Removes an empty department using the management service's guard and audit. */
@Component
public final class DepartmentDeleteAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> PREVIEW_FIELDS =
            Set.of("departmentId", "departmentName", "departmentCode", "parentDepartmentId", "sortNo", "status");
    private final OrgService service;

    public DepartmentDeleteAgentWriteHandler(OrgService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.DEPARTMENT_DELETE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("departmentId").containsAll(parameters.keySet())) throw new IllegalArgumentException("部门参数不合法");
        Object raw = parameters.get("departmentId");
        if (!(raw instanceof String id) || !id.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("部门编号不合法");
        try {
            Long.parseLong(id);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("部门编号不合法", invalid);
        }
        return Map.of("departmentId", id);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String id = (String) parameters.get("departmentId");
        var current = service.previewDepartmentDeletion(id);
        return Map.of(
                "departmentId", id,
                "departmentName", current.name(),
                "departmentCode", current.code(),
                "parentDepartmentId", current.parentId() == null ? "" : current.parentId(),
                "sortNo", Integer.toString(current.sortNo()),
                "status", current.status());
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "删除部门 " + previewFields.get("departmentCode");
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
                || !Objects.equals(normalized.get("departmentId"), previewFields.get("departmentId")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        int sortNo;
        try {
            sortNo = Integer.parseInt(previewFields.get("sortNo"));
        } catch (NumberFormatException invalid) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        }
        String id = (String) normalized.get("departmentId");
        service.deleteDepartmentForAgent(
                id,
                new DepartmentDeleteExpectation(
                        previewFields.get("departmentName"),
                        previewFields.get("departmentCode"),
                        previewFields.get("parentDepartmentId").isEmpty()
                                ? null
                                : previewFields.get("parentDepartmentId"),
                        sortNo,
                        previewFields.get("status")),
                actor,
                metadata);
        return new LocalAgentWriteResult(id, null);
    }
}
