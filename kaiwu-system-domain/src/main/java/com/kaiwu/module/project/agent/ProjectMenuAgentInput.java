package com.kaiwu.module.project.agent;

import com.kaiwu.module.project.dto.ProjectMenuRequest;
import jakarta.validation.Validator;
import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

/** The same bounded full-menu form is used for creation and replacement. */
final class ProjectMenuAgentInput {
    private static final Set<String> FIELDS = Set.of(
            "projectId",
            "targetMenuId",
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

    private ProjectMenuAgentInput() {}

    static Map<String, Object> normalize(Map<String, Object> raw, boolean update, Validator validator) {
        if (!FIELDS.containsAll(raw.keySet())) throw new IllegalArgumentException("项目菜单参数不合法");
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("projectId", ProjectMenuWriteIds.id(raw.get("projectId")));
        if (update) values.put("targetMenuId", ProjectMenuWriteIds.id(raw.get("targetMenuId")));
        else if (raw.containsKey("targetMenuId")) throw new IllegalArgumentException("新增菜单不能指定目标编号");
        String parentId = optional(raw, "parentId", 19);
        if (!parentId.isEmpty()) ProjectMenuWriteIds.id(parentId);
        values.put("parentId", parentId);
        values.put("menuName", required(raw, "menuName", 100));
        values.put("menuNameKey", optional(raw, "menuNameKey", 160));
        String type = required(raw, "menuType", 6);
        if (!Set.of("DIR", "MENU", "BUTTON").contains(type)) throw new IllegalArgumentException("菜单类型不合法");
        values.put("menuType", type);
        values.put("routePath", optional(raw, "routePath", 256));
        values.put("componentPath", optional(raw, "componentPath", 256));
        values.put("permissionCode", optional(raw, "permissionCode", 128));
        values.put("icon", optional(raw, "icon", 64));
        values.put("sortNo", integer(raw.get("sortNo")));
        Object visible = raw.getOrDefault("visible", true);
        if (!(visible instanceof Boolean)) throw new IllegalArgumentException("菜单显示状态不合法");
        values.put("visible", visible);
        if (!validator.validate(request(values)).isEmpty()) throw new IllegalArgumentException("项目菜单参数不合法");
        return Map.copyOf(values);
    }

    static ProjectMenuRequest request(Map<String, Object> values) {
        return new ProjectMenuRequest(
                nullable(values, "parentId"),
                (String) values.get("menuName"),
                nullable(values, "menuNameKey"),
                (String) values.get("menuType"),
                nullable(values, "routePath"),
                nullable(values, "componentPath"),
                nullable(values, "permissionCode"),
                nullable(values, "icon"),
                (Integer) values.get("sortNo"),
                (Boolean) values.get("visible"));
    }

    static String text(Map<String, Object> values, String key) {
        Object value = values.get(key);
        return value == null ? "" : value.toString();
    }

    private static String nullable(Map<String, Object> values, String key) {
        String value = (String) values.get(key);
        return value.isEmpty() ? null : value;
    }

    private static String required(Map<String, Object> values, String key, int max) {
        String value = optional(values, key, max);
        if (value.isEmpty()) throw new IllegalArgumentException("缺少项目菜单必填信息");
        return value;
    }

    private static String optional(Map<String, Object> values, String key, int max) {
        Object raw = values.get(key);
        if (raw == null) return "";
        if (!(raw instanceof String text)) throw new IllegalArgumentException("项目菜单参数类型不合法");
        String value = text.trim();
        if (value.length() > max) throw new IllegalArgumentException("项目菜单参数过长");
        return value;
    }

    private static int integer(Object raw) {
        if (raw == null) return 0;
        if (!(raw instanceof Number number)) throw new IllegalArgumentException("排序值类型不合法");
        try {
            int value = new BigDecimal(number.toString()).intValueExact();
            if (value < 0 || value > 9999) throw new IllegalArgumentException("排序值超出范围");
            return value;
        } catch (ArithmeticException invalid) {
            throw new IllegalArgumentException("排序值不合法", invalid);
        }
    }
}
