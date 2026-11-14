package com.kaiwu.module.configuration.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.configuration.service.MetadataService.DictItemDeleteSnapshot;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Deletes one global dictionary item only after strong confirmation of its frozen identity. */
@Component
public final class DictItemDeleteAgentWriteHandler implements LocalAgentWriteHandler {
    private final MetadataService service;

    public DictItemDeleteAgentWriteHandler(MetadataService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.DICT_ITEM_DELETE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("typeId", "itemId").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("字典项删除参数不合法");
        return Map.of("typeId", id(parameters, "typeId"), "itemId", id(parameters, "itemId"));
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String typeId = (String) parameters.get("typeId");
        String itemId = (String) parameters.get("itemId");
        var snapshot = service.previewGlobalDictItemDeletion(typeId, itemId);
        return Map.of(
                "typeId", typeId,
                "itemId", itemId,
                "itemLabel", snapshot.itemLabel(),
                "itemValue", snapshot.itemValue(),
                "status", snapshot.status());
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "删除字典项 " + previewFields.get("itemId") + " " + previewFields.get("itemValue");
    }

    @Override
    public LocalAgentWriteResult executeForAction(
            Map<String, Object> parameters,
            Map<String, String> previewFields,
            KaiwuContext actor,
            RequestMetadata metadata) {
        if (previewFields == null
                || !previewFields.keySet().containsAll(Set.of("typeId", "itemId", "itemLabel", "itemValue", "status"))
                || !parameters.get("typeId").equals(previewFields.get("typeId"))
                || !parameters.get("itemId").equals(previewFields.get("itemId")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String itemId = (String) parameters.get("itemId");
        service.deleteGlobalDictItemForAgent(
                (String) parameters.get("typeId"),
                itemId,
                new DictItemDeleteSnapshot(
                        previewFields.get("itemLabel"), previewFields.get("itemValue"), previewFields.get("status")),
                actor,
                metadata);
        return new LocalAgentWriteResult(itemId, null);
    }

    private static String id(Map<String, Object> parameters, String key) {
        if (!(parameters.get(key) instanceof String id) || !id.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("字典项 ID 不合法");
        try {
            Long.parseLong(id);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("字典项 ID 不合法", invalid);
        }
        return id;
    }
}
