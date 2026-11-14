package com.kaiwu.module.configuration.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.configuration.service.MetadataService.DictTypeDeleteSnapshot;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Deletes a global dictionary type and its items only after a frozen, strongly confirmed preview. */
@Component
public final class DictTypeDeleteAgentWriteHandler implements LocalAgentWriteHandler {
    private final MetadataService service;

    public DictTypeDeleteAgentWriteHandler(MetadataService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.DICT_TYPE_DELETE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("typeId").containsAll(parameters.keySet())) throw new IllegalArgumentException("字典类型参数不合法");
        if (!(parameters.get("typeId") instanceof String id) || !id.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("字典类型 ID 不合法");
        try {
            Long.parseLong(id);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("字典类型 ID 不合法", invalid);
        }
        return Map.of("typeId", id);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String id = (String) parameters.get("typeId");
        var snapshot = service.previewGlobalDictTypeDeletion(id);
        return Map.of(
                "typeId", id,
                "dictCode", snapshot.dictCode(),
                "dictName", snapshot.dictName(),
                "status", snapshot.status(),
                "itemCount", Integer.toString(snapshot.itemCount()),
                "_fingerprint", snapshot.fingerprint());
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "删除字典 " + previewFields.get("typeId") + " " + previewFields.get("dictCode");
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
                        .containsAll(Set.of("typeId", "dictCode", "dictName", "status", "itemCount", "_fingerprint"))
                || !parameters.get("typeId").equals(previewFields.get("typeId")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        int itemCount;
        try {
            itemCount = Integer.parseInt(previewFields.get("itemCount"));
        } catch (NumberFormatException invalid) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        }
        String id = (String) parameters.get("typeId");
        service.deleteGlobalDictTypeForAgent(
                id,
                new DictTypeDeleteSnapshot(
                        previewFields.get("dictCode"),
                        previewFields.get("dictName"),
                        previewFields.get("status"),
                        itemCount,
                        previewFields.get("_fingerprint")),
                actor,
                metadata);
        return new LocalAgentWriteResult(id, null);
    }
}
