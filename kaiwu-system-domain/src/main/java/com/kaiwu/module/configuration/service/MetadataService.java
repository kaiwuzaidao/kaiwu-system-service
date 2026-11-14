package com.kaiwu.module.configuration.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.metadata.dto.ConfigSaveRequest;
import com.kaiwu.module.metadata.dto.DictItemSaveRequest;
import com.kaiwu.module.metadata.dto.DictTypeSaveRequest;
import com.kaiwu.module.metadata.vo.*;
import com.kaiwu.starter.KaiwuContext;
import java.util.*;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface MetadataService {

    List<ConfigView> configs(String scopeId);

    /** 已登录用户可读取的受限平台界面参数。 */
    Map<String, Integer> platformUiPreferences();

    ConfigView saveConfig(String scopeId, ConfigSaveRequest request, KaiwuContext actor, RequestMetadata metadata);

    void deleteConfig(String scopeId, String id, KaiwuContext actor, RequestMetadata metadata);

    ConfigDeleteSnapshot previewGlobalConfigDeletion(String id);

    void deleteGlobalConfigForAgent(
            String id, ConfigDeleteSnapshot expected, KaiwuContext actor, RequestMetadata metadata);

    List<EffectiveConfigView> effectiveConfigs(String projectId, String userId, String language);

    List<EffectiveConfigView> effectiveConfigsOfProject(String projectId);

    List<EffectiveConfigView> effectiveConfigsOfProject(String projectId, String language, boolean anonymous);

    List<DictTypeView> dictTypes(String scopeId);

    DictTypeView saveDictType(
            String scopeId, DictTypeSaveRequest request, KaiwuContext actor, RequestMetadata metadata);

    DictTypeView renameGlobalDictType(
            String id,
            String newName,
            DictTypeRenameExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    DictTypeDeleteSnapshot previewGlobalDictTypeDeletion(String id);

    void deleteGlobalDictTypeForAgent(
            String id, DictTypeDeleteSnapshot expected, KaiwuContext actor, RequestMetadata metadata);

    void deleteDictType(String scopeId, String id, KaiwuContext actor, RequestMetadata metadata);

    void sortDictTypes(String scopeId, List<String> ids, KaiwuContext actor, RequestMetadata metadata);

    void sortDictItems(String scopeId, String typeId, List<String> ids, KaiwuContext actor, RequestMetadata metadata);

    List<DictItemView> dictItems(String scopeId, String typeId);

    DictItemView saveDictItem(
            String scopeId, String typeId, DictItemSaveRequest request, KaiwuContext actor, RequestMetadata metadata);

    DictItemView renameGlobalDictItem(
            String typeId,
            String itemId,
            String newLabel,
            DictItemRenameExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    DictItemDeleteSnapshot previewGlobalDictItemDeletion(String typeId, String itemId);

    void deleteGlobalDictItemForAgent(
            String typeId,
            String itemId,
            DictItemDeleteSnapshot expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    void deleteDictItem(String scopeId, String typeId, String itemId, KaiwuContext actor, RequestMetadata metadata);

    EffectiveDictView platformDict(String dictCode, String language);

    EffectiveDictView effectiveDict(String projectId, String dictCode, String userId);

    EffectiveDictView effectiveDict(String projectId, String dictCode, String userId, String language);

    public static final String GLOBAL_SCOPE = "0";

    public static final String MASKED_VALUE = "******";

    public record ConfigDeleteSnapshot(
            String configKey, String valueType, boolean secret, String status, String fingerprint) {}

    public record DictTypeRenameExpectation(String dictCode, String dictName, String status, String description) {}

    public record DictTypeDeleteSnapshot(
            String dictCode, String dictName, String status, int itemCount, String fingerprint) {}

    public record DictItemRenameExpectation(String itemLabel, String itemValue, String status) {}

    public record DictItemDeleteSnapshot(String itemLabel, String itemValue, String status) {}
}
