package com.kaiwu.module.configuration.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.metadata.dto.DictItemSaveRequest;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.starter.KaiwuContext;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Creates one global dictionary item through the existing metadata service. */
@Component
public final class DictItemCreateAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> FIELDS =
            Set.of("typeId", "itemLabel", "itemValue", "sortNo", "defaultItem", "color", "labelI18nKey", "status");
    private final MetadataService service;

    public DictItemCreateAgentWriteHandler(MetadataService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.DICT_ITEM_CREATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!FIELDS.containsAll(parameters.keySet())) throw new IllegalArgumentException("字典项参数不合法");
        String typeId = required(parameters, "typeId", 19);
        if (!typeId.matches("[1-9][0-9]{0,18}")) throw new IllegalArgumentException("字典类型 ID 不合法");
        try {
            Long.parseLong(typeId);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("字典类型 ID 不合法", invalid);
        }
        String label = required(parameters, "itemLabel", 128);
        String value = required(parameters, "itemValue", 128);
        int sortNo = integer(parameters.get("sortNo"), 0);
        boolean defaultItem = bool(parameters.get("defaultItem"), false);
        String color = optional(parameters, "color", 32);
        String labelI18nKey = optional(parameters, "labelI18nKey", 160);
        String status = optional(parameters, "status", 8);
        if (status == null) status = "ENABLED";
        if (!Set.of("ENABLED", "DISABLED").contains(status)) throw new IllegalArgumentException("字典项状态不合法");
        Map<String, Object> normalized = new LinkedHashMap<>();
        normalized.put("typeId", typeId);
        normalized.put("itemLabel", label);
        normalized.put("itemValue", value);
        normalized.put("sortNo", sortNo);
        normalized.put("defaultItem", defaultItem);
        normalized.put("status", status);
        if (color != null) normalized.put("color", color);
        if (labelI18nKey != null) normalized.put("labelI18nKey", labelI18nKey);
        return normalized;
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String typeId = (String) parameters.get("typeId");
        var type = service.dictTypes("0").stream()
                .filter(row -> typeId.equals(row.id()))
                .findFirst()
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "字典类型不存在", "api.common.notFound"));
        return Map.of(
                "dictName", type.dictName(),
                "itemLabel", (String) parameters.get("itemLabel"),
                "itemValue", (String) parameters.get("itemValue"),
                "status", (String) parameters.get("status"));
    }

    @Override
    public String execute(Map<String, Object> parameters, KaiwuContext actor, RequestMetadata metadata) {
        var request = new DictItemSaveRequest(
                null,
                (String) parameters.get("itemLabel"),
                (String) parameters.get("itemValue"),
                (Integer) parameters.get("sortNo"),
                (Boolean) parameters.get("defaultItem"),
                (String) parameters.get("color"),
                null,
                (String) parameters.get("labelI18nKey"),
                (String) parameters.get("status"));
        return service.saveDictItem("0", (String) parameters.get("typeId"), request, actor, metadata)
                .id();
    }

    private static int integer(Object raw, int fallback) {
        if (raw == null) return fallback;
        if (!(raw instanceof Number number)) throw new IllegalArgumentException("排序值类型不合法");
        try {
            int value = new java.math.BigDecimal(number.toString()).intValueExact();
            if (value < 0 || value > 9999) throw new IllegalArgumentException("排序值超出范围");
            return value;
        } catch (ArithmeticException invalid) {
            throw new IllegalArgumentException("排序值不合法", invalid);
        }
    }

    private static boolean bool(Object raw, boolean fallback) {
        if (raw == null) return fallback;
        if (!(raw instanceof Boolean value)) throw new IllegalArgumentException("默认项类型不合法");
        return value;
    }

    private static String required(Map<String, Object> values, String key, int max) {
        String value = optional(values, key, max);
        if (value == null) throw new IllegalArgumentException("缺少字典项必填信息");
        return value;
    }

    private static String optional(Map<String, Object> values, String key, int max) {
        Object raw = values.get(key);
        if (raw == null) return null;
        if (!(raw instanceof String text)) throw new IllegalArgumentException("字典项参数类型不合法");
        String value = text.trim();
        if (value.length() > max) throw new IllegalArgumentException("字典项参数过长");
        return value.isEmpty() ? null : value;
    }
}
