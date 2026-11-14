package com.kaiwu.module.configuration.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.configuration.service.MetadataService.ConfigDeleteSnapshot;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Deletes a global configuration without exposing its current value to the chat. */
@Component
public final class ConfigDeleteAgentWriteHandler implements LocalAgentWriteHandler {
    private final MetadataService service;

    public ConfigDeleteAgentWriteHandler(MetadataService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.CONFIG_DELETE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("configId").containsAll(parameters.keySet())
                || !(parameters.get("configId") instanceof String id)
                || !id.matches("[1-9][0-9]{0,18}")) throw new IllegalArgumentException("配置 ID 不合法");
        try {
            Long.parseLong(id);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("配置 ID 不合法", invalid);
        }
        return Map.of("configId", id);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String id = (String) parameters.get("configId");
        ConfigDeleteSnapshot snapshot = service.previewGlobalConfigDeletion(id);
        return Map.of(
                "configId", id,
                "configKey", snapshot.configKey(),
                "valueType", snapshot.valueType(),
                "secret", snapshot.secret() ? "是" : "否",
                "status", snapshot.status(),
                "_fingerprint", snapshot.fingerprint());
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "删除配置 " + previewFields.get("configKey");
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
                        .containsAll(Set.of("configId", "configKey", "valueType", "secret", "status", "_fingerprint"))
                || !parameters.get("configId").equals(previewFields.get("configId")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String id = (String) parameters.get("configId");
        service.deleteGlobalConfigForAgent(
                id,
                new ConfigDeleteSnapshot(
                        previewFields.get("configKey"),
                        previewFields.get("valueType"),
                        "是".equals(previewFields.get("secret")),
                        previewFields.get("status"),
                        previewFields.get("_fingerprint")),
                actor,
                metadata);
        return new LocalAgentWriteResult(id, null);
    }
}
