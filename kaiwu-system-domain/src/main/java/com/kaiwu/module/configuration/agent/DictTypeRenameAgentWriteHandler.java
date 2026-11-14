package com.kaiwu.module.configuration.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.configuration.service.MetadataService.DictTypeRenameExpectation;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.starter.KaiwuContext;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Renames a global dictionary without changing its code, status, order or items. */
@Component
public final class DictTypeRenameAgentWriteHandler implements LocalAgentWriteHandler {
    private final MetadataService service;

    public DictTypeRenameAgentWriteHandler(MetadataService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.DICT_TYPE_RENAME;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("typeId", "dictName").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("字典参数不合法");
        if (!(parameters.get("typeId") instanceof String id) || !id.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("字典类型 ID 不合法");
        try {
            Long.parseLong(id);
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("字典类型 ID 不合法", invalid);
        }
        if (!(parameters.get("dictName") instanceof String raw)) throw new IllegalArgumentException("字典名称不合法");
        String name = raw.trim();
        if (name.isEmpty() || name.length() > 128) throw new IllegalArgumentException("字典名称不合法");
        return Map.of("typeId", id, "dictName", name);
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String id = (String) parameters.get("typeId");
        var current = service.dictTypes("0").stream()
                .filter(row -> id.equals(row.id()))
                .findFirst()
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "字典不存在", "api.common.notFound"));
        if (current.dictNameKey() != null && !current.dictNameKey().isBlank())
            throw new ApiException(HttpStatus.BAD_REQUEST, "引用国际化资源的字典需在资源目录修改名称", "api.common.badRequest");
        if (current.dictName().equals(parameters.get("dictName")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "字典名称没有变化", "api.common.badRequest");
        return Map.of(
                "typeId",
                id,
                "dictCode",
                current.dictCode(),
                "currentName",
                current.dictName(),
                "dictName",
                (String) parameters.get("dictName"),
                "status",
                current.status(),
                "description",
                current.description() == null ? "" : current.description());
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
                        .containsAll(Set.of("typeId", "dictCode", "currentName", "dictName", "status", "description"))
                || !parameters.get("typeId").equals(previewFields.get("typeId"))
                || !parameters.get("dictName").equals(previewFields.get("dictName")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        var expected = new DictTypeRenameExpectation(
                previewFields.get("dictCode"), previewFields.get("currentName"),
                previewFields.get("status"), previewFields.get("description"));
        String id = (String) parameters.get("typeId");
        service.renameGlobalDictType(id, (String) parameters.get("dictName"), expected, actor, metadata);
        return new LocalAgentWriteResult(id, null);
    }
}
