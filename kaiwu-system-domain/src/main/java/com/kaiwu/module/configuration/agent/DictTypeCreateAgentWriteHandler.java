package com.kaiwu.module.configuration.agent;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.metadata.dto.DictTypeSaveRequest;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.starter.KaiwuContext;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Component;

/** Create a global dictionary type through the same Service used by its management page. */
@Component
public final class DictTypeCreateAgentWriteHandler implements LocalAgentWriteHandler {
    private final MetadataService service;

    public DictTypeCreateAgentWriteHandler(MetadataService metadata) {
        this.service = metadata;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.DICT_TYPE_CREATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("dictCode", "dictName", "description").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("字典参数不合法");
        String code = required(parameters, "dictCode", 128);
        String name = required(parameters, "dictName", 128);
        if (!code.matches("[A-Za-z][A-Za-z0-9_.:-]{1,127}")) throw new IllegalArgumentException("字典编码格式不正确");
        String description = optional(parameters, "description", 512);
        Map<String, Object> normalized = new LinkedHashMap<>();
        normalized.put("dictCode", code);
        normalized.put("dictName", name);
        if (description != null) normalized.put("description", description);
        return normalized;
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        return Map.of(
                "dictCode", (String) parameters.get("dictCode"),
                "dictName", (String) parameters.get("dictName"),
                "description", (String) parameters.getOrDefault("description", "-"));
    }

    @Override
    public String execute(Map<String, Object> parameters, KaiwuContext actor, RequestMetadata metadata) {
        var request = new DictTypeSaveRequest(
                null,
                (String) parameters.get("dictCode"),
                (String) parameters.get("dictName"),
                null,
                false,
                "ENABLED",
                (String) parameters.get("description"));
        return service.saveDictType("0", request, actor, metadata).id();
    }

    private static String required(Map<String, Object> values, String key, int max) {
        String value = optional(values, key, max);
        if (value == null) throw new IllegalArgumentException("缺少字典必填信息");
        return value;
    }

    private static String optional(Map<String, Object> values, String key, int max) {
        Object raw = values.get(key);
        if (raw == null) return null;
        if (!(raw instanceof String text)) throw new IllegalArgumentException("字典参数类型不合法");
        String value = text.trim();
        if (value.length() > max) throw new IllegalArgumentException("字典参数过长");
        return value.isEmpty() ? null : value;
    }
}
