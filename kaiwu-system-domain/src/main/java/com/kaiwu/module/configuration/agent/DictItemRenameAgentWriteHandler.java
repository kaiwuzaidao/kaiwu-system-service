package com.kaiwu.module.configuration.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.configuration.service.MetadataService.DictItemRenameExpectation;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.starter.KaiwuContext;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Renames one global dictionary item while preserving its stable value and other settings. */
@Component
public final class DictItemRenameAgentWriteHandler implements LocalAgentWriteHandler {
    private final MetadataService service;

    public DictItemRenameAgentWriteHandler(MetadataService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.DICT_ITEM_RENAME;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("typeId", "itemId", "itemLabel").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("字典项参数不合法");
        String typeId = id(parameters, "typeId");
        String itemId = id(parameters, "itemId");
        if (!(parameters.get("itemLabel") instanceof String raw)) throw new IllegalArgumentException("字典项标签不合法");
        String label = raw.trim();
        if (label.isEmpty() || label.length() > 128) throw new IllegalArgumentException("字典项标签不合法");
        return Map.of("typeId", typeId, "itemId", itemId, "itemLabel", label);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String typeId = (String) parameters.get("typeId");
        String itemId = (String) parameters.get("itemId");
        var current = service.dictItems("0", typeId).stream()
                .filter(row -> itemId.equals(row.id()))
                .findFirst()
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "字典项不存在", "api.common.notFound"));
        if (current.labelI18nKey() != null && !current.labelI18nKey().isBlank())
            throw new ApiException(HttpStatus.BAD_REQUEST, "引用国际化资源的字典项需在资源目录修改标签", "api.common.badRequest");
        if (current.itemLabel().equals(parameters.get("itemLabel")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "字典项标签没有变化", "api.common.badRequest");
        return Map.of(
                "typeId",
                typeId,
                "itemId",
                itemId,
                "currentLabel",
                current.itemLabel(),
                "itemLabel",
                (String) parameters.get("itemLabel"),
                "itemValue",
                current.itemValue(),
                "status",
                current.status());
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
                        .containsAll(Set.of("typeId", "itemId", "currentLabel", "itemLabel", "itemValue", "status"))
                || !parameters.get("typeId").equals(previewFields.get("typeId"))
                || !parameters.get("itemId").equals(previewFields.get("itemId"))
                || !parameters.get("itemLabel").equals(previewFields.get("itemLabel")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String itemId = (String) parameters.get("itemId");
        var expected = new DictItemRenameExpectation(
                previewFields.get("currentLabel"), previewFields.get("itemValue"), previewFields.get("status"));
        service.renameGlobalDictItem(
                (String) parameters.get("typeId"),
                itemId,
                (String) parameters.get("itemLabel"),
                expected,
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
