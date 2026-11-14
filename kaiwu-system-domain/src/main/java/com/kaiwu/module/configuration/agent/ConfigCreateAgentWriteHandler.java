package com.kaiwu.module.configuration.agent;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.metadata.dto.ConfigSaveRequest;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.starter.KaiwuContext;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Component;

/** Creates a non-secret global configuration through the existing management service. */
@Component
public final class ConfigCreateAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> FIELDS = Set.of("configKey", "configValue", "valueType", "description");
    private static final Set<String> VALUE_TYPES = Set.of("STRING", "NUMBER", "BOOLEAN", "JSON");
    private final MetadataService service;

    public ConfigCreateAgentWriteHandler(MetadataService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.CONFIG_CREATE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!FIELDS.containsAll(parameters.keySet())) throw new IllegalArgumentException("配置参数不合法");
        String key = required(parameters, "configKey", 128);
        if (!key.matches("[A-Za-z][A-Za-z0-9_.:-]{1,127}")) throw new IllegalArgumentException("配置键格式不正确");
        String value = required(parameters, "configValue", 1000);
        String type = optional(parameters, "valueType", 16);
        if (type == null) type = "STRING";
        if (!VALUE_TYPES.contains(type)) throw new IllegalArgumentException("配置值类型不合法");
        String description = optional(parameters, "description", 512);
        Map<String, Object> normalized = new LinkedHashMap<>();
        normalized.put("configKey", key);
        normalized.put("configValue", value);
        normalized.put("valueType", type);
        if (description != null) normalized.put("description", description);
        return normalized;
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        return Map.of(
                "configKey", (String) parameters.get("configKey"),
                "configValue", (String) parameters.get("configValue"),
                "valueType", (String) parameters.get("valueType"),
                "description", (String) parameters.getOrDefault("description", "-"));
    }

    @Override
    public String execute(Map<String, Object> parameters, KaiwuContext actor, RequestMetadata metadata) {
        var request = new ConfigSaveRequest(
                null,
                (String) parameters.get("configKey"),
                (String) parameters.get("configValue"),
                null,
                (String) parameters.get("valueType"),
                false,
                "ENABLED",
                (String) parameters.get("description"),
                0);
        return service.saveConfig("0", request, actor, metadata).id();
    }

    private static String required(Map<String, Object> values, String key, int max) {
        String value = optional(values, key, max);
        if (value == null) throw new IllegalArgumentException("缺少配置必填信息");
        return value;
    }

    private static String optional(Map<String, Object> values, String key, int max) {
        Object raw = values.get(key);
        if (raw == null) return null;
        if (!(raw instanceof String text)) throw new IllegalArgumentException("配置参数类型不合法");
        String value = text.trim();
        if (value.length() > max) throw new IllegalArgumentException("配置参数过长");
        return value.isEmpty() ? null : value;
    }
}
