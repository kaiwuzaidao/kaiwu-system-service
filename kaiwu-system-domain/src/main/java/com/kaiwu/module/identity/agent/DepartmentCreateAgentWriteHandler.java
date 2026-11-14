package com.kaiwu.module.identity.agent;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.service.OrgService;
import com.kaiwu.module.org.dto.DepartmentSaveRequest;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.starter.KaiwuContext;
import jakarta.validation.Validator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Component;

/** Creates a department through OrgService; tree constraints remain enforced by that service. */
@Component
public final class DepartmentCreateAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> FIELDS =
            Set.of("departmentName", "departmentCode", "parentDepartmentId", "sortNo", "status");
    private final OrgService service;
    private final Validator validator;

    public DepartmentCreateAgentWriteHandler(OrgService service, Validator validator) {
        this.service = service;
        this.validator = validator;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.DEPARTMENT_CREATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!FIELDS.containsAll(parameters.keySet())) throw new IllegalArgumentException("部门参数不合法");
        String name = required(parameters, "departmentName", 100);
        String code = required(parameters, "departmentCode", 64);
        String parentId = optional(parameters, "parentDepartmentId", 19);
        if (parentId != null) {
            if (!parentId.matches("[1-9][0-9]{0,18}")) throw new IllegalArgumentException("上级部门 ID 不合法");
            try {
                Long.parseLong(parentId);
            } catch (NumberFormatException invalid) {
                throw new IllegalArgumentException("上级部门 ID 不合法", invalid);
            }
        }
        int sortNo = integer(parameters.get("sortNo"));
        String status = optional(parameters, "status", 8);
        if (status == null) status = "ENABLED";
        if (!validator
                .validate(new DepartmentSaveRequest(null, parentId, name, code, sortNo, status))
                .isEmpty()) throw new IllegalArgumentException("部门参数不合法");
        Map<String, Object> normalized = new LinkedHashMap<>();
        normalized.put("departmentName", name);
        normalized.put("departmentCode", code);
        normalized.put("sortNo", sortNo);
        normalized.put("status", status);
        if (parentId != null) normalized.put("parentDepartmentId", parentId);
        return normalized;
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        return Map.of(
                "departmentName", (String) parameters.get("departmentName"),
                "departmentCode", (String) parameters.get("departmentCode"),
                "parentDepartmentId", (String) parameters.getOrDefault("parentDepartmentId", "-"),
                "status", (String) parameters.get("status"));
    }

    @Override
    public String execute(Map<String, Object> parameters, KaiwuContext actor, RequestMetadata metadata) {
        var request = new DepartmentSaveRequest(
                null,
                (String) parameters.get("parentDepartmentId"),
                (String) parameters.get("departmentName"),
                (String) parameters.get("departmentCode"),
                (Integer) parameters.get("sortNo"),
                (String) parameters.get("status"));
        return service.saveDepartment(request, actor, metadata).id();
    }

    private static int integer(Object raw) {
        if (raw == null) return 0;
        if (!(raw instanceof Number number)) throw new IllegalArgumentException("排序值类型不合法");
        try {
            int value = new java.math.BigDecimal(number.toString()).intValueExact();
            if (value < 0 || value > 9999) throw new IllegalArgumentException("排序值超出范围");
            return value;
        } catch (ArithmeticException invalid) {
            throw new IllegalArgumentException("排序值不合法", invalid);
        }
    }

    private static String required(Map<String, Object> values, String key, int max) {
        String value = optional(values, key, max);
        if (value == null) throw new IllegalArgumentException("缺少部门必填信息");
        return value;
    }

    private static String optional(Map<String, Object> values, String key, int max) {
        Object raw = values.get(key);
        if (raw == null) return null;
        if (!(raw instanceof String text)) throw new IllegalArgumentException("部门参数类型不合法");
        String value = text.trim();
        if (value.length() > max) throw new IllegalArgumentException("部门参数过长");
        return value.isEmpty() ? null : value;
    }
}
