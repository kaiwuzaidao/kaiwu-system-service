package com.kaiwu.module.metadata;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.kaiwu.module.metadata.entity.AppConfigEntity;
import com.kaiwu.module.metadata.entity.DictItemEntity;
import com.kaiwu.module.metadata.entity.DictTypeEntity;
import com.kaiwu.module.metadata.mapper.AppConfigMapper;
import com.kaiwu.module.metadata.mapper.DictItemMapper;
import com.kaiwu.module.metadata.mapper.DictTypeMapper;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import org.springframework.stereotype.Repository;
import org.springframework.util.StringUtils;

@Repository
public class MetadataRepository {

    /** 拖拽排序写入 sort_no 的步长；留空隙以便将来单条插入不必整表重排。 */
    public static final int SORT_STEP = 10;

    private final AppConfigMapper configMapper;
    private final DictTypeMapper dictTypeMapper;
    private final DictItemMapper dictItemMapper;
    private final Clock clock;

    public MetadataRepository(
            AppConfigMapper configMapper, DictTypeMapper dictTypeMapper, DictItemMapper dictItemMapper, Clock clock) {
        this.configMapper = configMapper;
        this.dictTypeMapper = dictTypeMapper;
        this.dictItemMapper = dictItemMapper;
        this.clock = clock;
    }

    /**
     * 某作用域下的参数配置。
     *
     * @param scopeId     0 为平台全局，其余为项目 ID
     * @param enabledOnly true 时只返回 ENABLED，供运行期读取；管理页面传 false 看全量
     */
    public List<ConfigRow> configs(String scopeId, boolean enabledOnly) {
        LambdaQueryWrapper<AppConfigEntity> query = new LambdaQueryWrapper<AppConfigEntity>()
                .eq(AppConfigEntity::getScopeId, Long.parseLong(scopeId))
                .eq(enabledOnly, AppConfigEntity::getStatus, "ENABLED")
                .orderByAsc(AppConfigEntity::getSortNo)
                .orderByAsc(AppConfigEntity::getConfigKey)
                .orderByAsc(AppConfigEntity::getId);
        return configMapper.selectList(query).stream()
                .map(MetadataRepository::toConfig)
                .toList();
    }

    public Optional<ConfigRow> config(String id) {
        return Optional.ofNullable(configMapper.selectById(Long.parseLong(id))).map(MetadataRepository::toConfig);
    }

    /**
     * 配置键在作用域内是否已被占用。
     *
     * @param excludedId 编辑时传入自身 ID 以排除，否则「改值不改键」会被误判为重复
     */
    public boolean configKeyExists(String scopeId, String key, String excludedId) {
        LambdaQueryWrapper<AppConfigEntity> query = new LambdaQueryWrapper<AppConfigEntity>()
                .eq(AppConfigEntity::getScopeId, Long.parseLong(scopeId))
                .eq(AppConfigEntity::getConfigKey, key);
        if (StringUtils.hasText(excludedId)) {
            query.ne(AppConfigEntity::getId, Long.parseLong(excludedId));
        }
        return configMapper.exists(query);
    }

    /**
     * 新增或编辑参数配置。
     *
     * <p>编辑走显式 {@code set()}：描述、国际化 key 都允许被清空，而
     * {@code updateById} 会跳过 null 字段，导致清空操作静默失效。</p>
     */
    public void saveConfig(ConfigRow row, boolean insert) {
        if (insert) {
            AppConfigEntity entity = new AppConfigEntity();
            entity.setId(Long.parseLong(row.id()));
            entity.setScopeId(Long.parseLong(row.scopeId()));
            entity.setConfigKey(row.configKey());
            entity.setConfigValue(row.configValue());
            entity.setValueI18nKey(row.valueI18nKey());
            entity.setValueType(row.valueType());
            entity.setSecret(row.secret());
            entity.setStatus(row.status());
            entity.setDescription(row.description());
            entity.setSortNo(row.sortNo());
            LocalDateTime now = LocalDateTime.now(clock);
            entity.setCreatedAt(now);
            entity.setUpdatedAt(now);
            configMapper.insert(entity);
            return;
        }
        configMapper.update(
                null,
                new LambdaUpdateWrapper<AppConfigEntity>()
                        .eq(AppConfigEntity::getId, Long.parseLong(row.id()))
                        .set(AppConfigEntity::getConfigKey, row.configKey())
                        .set(AppConfigEntity::getConfigValue, row.configValue())
                        .set(AppConfigEntity::getValueI18nKey, row.valueI18nKey())
                        .set(AppConfigEntity::getValueType, row.valueType())
                        .set(AppConfigEntity::getSecret, row.secret())
                        .set(AppConfigEntity::getStatus, row.status())
                        .set(AppConfigEntity::getDescription, row.description())
                        .set(AppConfigEntity::getSortNo, row.sortNo())
                        .set(AppConfigEntity::getUpdatedAt, LocalDateTime.now(clock)));
    }

    public void deleteConfig(String id) {
        configMapper.deleteById(Long.parseLong(id));
    }

    /**
     * 某作用域下的字典类型；语义与 {@link #configs} 的两个参数一致。
     *
     * <p>排序键以 {@code sort_no} 打头，其后仍是原来的名称/编码/ID。存量行的
     * {@code sort_no} 都是 0，因此在第一次拖拽之前顺序与改造前完全一致。</p>
     */
    public List<DictTypeRow> dictTypes(String scopeId, boolean enabledOnly) {
        LambdaQueryWrapper<DictTypeEntity> query = new LambdaQueryWrapper<DictTypeEntity>()
                .eq(DictTypeEntity::getScopeId, Long.parseLong(scopeId))
                .eq(enabledOnly, DictTypeEntity::getStatus, "ENABLED")
                .orderByAsc(DictTypeEntity::getSortNo)
                .orderByAsc(DictTypeEntity::getDictName)
                .orderByAsc(DictTypeEntity::getDictCode)
                .orderByAsc(DictTypeEntity::getId);
        return dictTypeMapper.selectList(query).stream()
                .map(MetadataRepository::toDictType)
                .toList();
    }

    public Optional<DictTypeRow> dictType(String id) {
        return Optional.ofNullable(dictTypeMapper.selectById(Long.parseLong(id)))
                .map(MetadataRepository::toDictType);
    }

    /** 按编码取启用中的字典类型；停用的字典不参与运行期解析，因此这里只认 ENABLED。 */
    public Optional<DictTypeRow> enabledDictType(String scopeId, String code) {
        return Optional.ofNullable(dictTypeMapper.selectOne(new LambdaQueryWrapper<DictTypeEntity>()
                        .eq(DictTypeEntity::getScopeId, Long.parseLong(scopeId))
                        .eq(DictTypeEntity::getDictCode, code)
                        .eq(DictTypeEntity::getStatus, "ENABLED")))
                .map(MetadataRepository::toDictType);
    }

    /** 字典编码在作用域内是否已被占用；{@code excludedId} 用法同 {@link #configKeyExists}。 */
    public boolean dictCodeExists(String scopeId, String code, String excludedId) {
        LambdaQueryWrapper<DictTypeEntity> query = new LambdaQueryWrapper<DictTypeEntity>()
                .eq(DictTypeEntity::getScopeId, Long.parseLong(scopeId))
                .eq(DictTypeEntity::getDictCode, code);
        if (StringUtils.hasText(excludedId)) {
            query.ne(DictTypeEntity::getId, Long.parseLong(excludedId));
        }
        return dictTypeMapper.exists(query);
    }

    /**
     * 新增或编辑字典类型。
     *
     * @param insert true 走插入；false 走显式 set() 更新——描述与国际化 key 允许清空，
     *               用实体更新会被 MyBatis-Plus 跳过 null 而静默失效
     */
    public void saveDictType(DictTypeRow row, boolean insert) {
        if (insert) {
            DictTypeEntity entity = new DictTypeEntity();
            entity.setId(Long.parseLong(row.id()));
            entity.setScopeId(Long.parseLong(row.scopeId()));
            entity.setDictCode(row.dictCode());
            entity.setDictName(row.dictName());
            entity.setDictNameKey(row.dictNameKey());
            entity.setInheritGlobal(row.inheritGlobal());
            entity.setSortNo(row.sortNo());
            entity.setStatus(row.status());
            entity.setDescription(row.description());
            LocalDateTime now = LocalDateTime.now(clock);
            entity.setCreatedAt(now);
            entity.setUpdatedAt(now);
            dictTypeMapper.insert(entity);
            return;
        }
        // sort_no 不在编辑表单里，由拖拽单独维护；这里显式写回调用方带来的既有值，
        // 保证一次普通编辑不会把拖出来的顺序重置掉。
        dictTypeMapper.update(
                null,
                new LambdaUpdateWrapper<DictTypeEntity>()
                        .eq(DictTypeEntity::getId, Long.parseLong(row.id()))
                        .set(DictTypeEntity::getDictCode, row.dictCode())
                        .set(DictTypeEntity::getDictName, row.dictName())
                        .set(DictTypeEntity::getDictNameKey, row.dictNameKey())
                        .set(DictTypeEntity::getInheritGlobal, row.inheritGlobal())
                        .set(DictTypeEntity::getSortNo, row.sortNo())
                        .set(DictTypeEntity::getStatus, row.status())
                        .set(DictTypeEntity::getDescription, row.description())
                        .set(DictTypeEntity::getUpdatedAt, LocalDateTime.now(clock)));
    }

    /** 作用域内已用的最大 sort_no；新建字典排到末尾用。 */
    public int maxDictTypeSortNo(String scopeId) {
        return dictTypeMapper
                .selectList(new LambdaQueryWrapper<DictTypeEntity>()
                        .eq(DictTypeEntity::getScopeId, Long.parseLong(scopeId))
                        .select(DictTypeEntity::getSortNo))
                .stream()
                .map(DictTypeEntity::getSortNo)
                .filter(Objects::nonNull)
                .max(Integer::compareTo)
                .orElse(0);
    }

    /**
     * 按给定顺序重写字典类型的 sort_no。
     *
     * <p>步长取 {@link #SORT_STEP} 而不是 1：留出空隙，将来插入单条时不必整表重排。</p>
     */
    public void resortDictTypes(List<String> orderedIds) {
        for (int index = 0; index < orderedIds.size(); index++) {
            dictTypeMapper.update(
                    null,
                    new LambdaUpdateWrapper<DictTypeEntity>()
                            .eq(DictTypeEntity::getId, Long.parseLong(orderedIds.get(index)))
                            .set(DictTypeEntity::getSortNo, (index + 1) * SORT_STEP)
                            .set(DictTypeEntity::getUpdatedAt, LocalDateTime.now(clock)));
        }
    }

    /** 按给定顺序重写字典项的 sort_no；语义同 {@link #resortDictTypes}。 */
    public void resortDictItems(List<String> orderedIds) {
        for (int index = 0; index < orderedIds.size(); index++) {
            dictItemMapper.update(
                    null,
                    new LambdaUpdateWrapper<DictItemEntity>()
                            .eq(DictItemEntity::getId, Long.parseLong(orderedIds.get(index)))
                            .set(DictItemEntity::getSortNo, (index + 1) * SORT_STEP)
                            .set(DictItemEntity::getUpdatedAt, LocalDateTime.now(clock)));
        }
    }

    /** 删除字典类型必须连同其字典项一起删，否则会留下查不到类型的孤儿项。 */
    public void deleteDictType(String id) {
        long typeId = Long.parseLong(id);
        dictItemMapper.delete(new LambdaQueryWrapper<DictItemEntity>().eq(DictItemEntity::getDictTypeId, typeId));
        dictTypeMapper.deleteById(typeId);
    }

    /** 某字典类型下的字典项，按 sort_no 排序；{@code enabledOnly} 语义同上。 */
    public List<DictItemRow> dictItems(String typeId, boolean enabledOnly) {
        LambdaQueryWrapper<DictItemEntity> query = new LambdaQueryWrapper<DictItemEntity>()
                .eq(DictItemEntity::getDictTypeId, Long.parseLong(typeId))
                .eq(enabledOnly, DictItemEntity::getStatus, "ENABLED")
                .orderByAsc(DictItemEntity::getSortNo)
                .orderByAsc(DictItemEntity::getId);
        return dictItemMapper.selectList(query).stream()
                .map(MetadataRepository::toDictItem)
                .toList();
    }

    public Optional<DictItemRow> dictItem(String id) {
        return Optional.ofNullable(dictItemMapper.selectById(Long.parseLong(id)))
                .map(MetadataRepository::toDictItem);
    }

    /** 字典项的值在同一类型内是否重复；{@code excludedId} 用法同 {@link #configKeyExists}。 */
    public boolean dictValueExists(String typeId, String value, String excludedId) {
        LambdaQueryWrapper<DictItemEntity> query = new LambdaQueryWrapper<DictItemEntity>()
                .eq(DictItemEntity::getDictTypeId, Long.parseLong(typeId))
                .eq(DictItemEntity::getItemValue, value);
        if (StringUtils.hasText(excludedId)) {
            query.ne(DictItemEntity::getId, Long.parseLong(excludedId));
        }
        return dictItemMapper.exists(query);
    }

    /**
     * 新增或编辑字典项。
     *
     * <p>{@code labelI18n} 一律写调用方传来的值（现为 null）：ADR 0015 退役了内联多语言，
     * 编辑时把该列显式置空，才能让存量库里的旧译文随着一次编辑被清掉。</p>
     */
    public void saveDictItem(DictItemRow row, boolean insert) {
        if (insert) {
            DictItemEntity entity = new DictItemEntity();
            entity.setId(Long.parseLong(row.id()));
            entity.setDictTypeId(Long.parseLong(row.dictTypeId()));
            entity.setItemLabel(row.itemLabel());
            entity.setItemValue(row.itemValue());
            entity.setSortNo(row.sortNo());
            entity.setDefaultItem(row.defaultItem());
            entity.setColor(row.color());
            entity.setExtraJson(row.extraJson());
            entity.setLabelI18n(row.labelI18n());
            entity.setLabelI18nKey(row.labelI18nKey());
            entity.setStatus(row.status());
            LocalDateTime now = LocalDateTime.now(clock);
            entity.setCreatedAt(now);
            entity.setUpdatedAt(now);
            dictItemMapper.insert(entity);
            return;
        }
        dictItemMapper.update(
                null,
                new LambdaUpdateWrapper<DictItemEntity>()
                        .eq(DictItemEntity::getId, Long.parseLong(row.id()))
                        .set(DictItemEntity::getItemLabel, row.itemLabel())
                        .set(DictItemEntity::getItemValue, row.itemValue())
                        .set(DictItemEntity::getSortNo, row.sortNo())
                        .set(DictItemEntity::getDefaultItem, row.defaultItem())
                        .set(DictItemEntity::getColor, row.color())
                        .set(DictItemEntity::getExtraJson, row.extraJson())
                        .set(DictItemEntity::getLabelI18n, row.labelI18n())
                        .set(DictItemEntity::getLabelI18nKey, row.labelI18nKey())
                        .set(DictItemEntity::getStatus, row.status())
                        .set(DictItemEntity::getUpdatedAt, LocalDateTime.now(clock)));
    }

    public void deleteDictItem(String id) {
        dictItemMapper.deleteById(Long.parseLong(id));
    }

    private static ConfigRow toConfig(AppConfigEntity entity) {
        return new ConfigRow(
                String.valueOf(entity.getId()),
                String.valueOf(entity.getScopeId()),
                entity.getConfigKey(),
                entity.getConfigValue(),
                entity.getValueI18nKey(),
                entity.getValueType(),
                Boolean.TRUE.equals(entity.getSecret()),
                entity.getStatus(),
                entity.getDescription(),
                entity.getSortNo() == null ? 0 : entity.getSortNo(),
                entity.getCreatedAt(),
                entity.getUpdatedAt());
    }

    private static DictTypeRow toDictType(DictTypeEntity entity) {
        return new DictTypeRow(
                String.valueOf(entity.getId()),
                String.valueOf(entity.getScopeId()),
                entity.getDictCode(),
                entity.getDictName(),
                entity.getDictNameKey(),
                Boolean.TRUE.equals(entity.getInheritGlobal()),
                entity.getSortNo() == null ? 0 : entity.getSortNo(),
                entity.getStatus(),
                entity.getDescription(),
                entity.getCreatedAt(),
                entity.getUpdatedAt());
    }

    private static DictItemRow toDictItem(DictItemEntity entity) {
        return new DictItemRow(
                String.valueOf(entity.getId()),
                String.valueOf(entity.getDictTypeId()),
                entity.getItemLabel(),
                entity.getItemValue(),
                entity.getSortNo() == null ? 0 : entity.getSortNo(),
                Boolean.TRUE.equals(entity.getDefaultItem()),
                entity.getColor(),
                entity.getExtraJson(),
                entity.getStatus(),
                entity.getLabelI18n(),
                entity.getLabelI18nKey());
    }

    public static String normalize(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }

    /**
     * @param valueI18nKey 展示型配置引用的国际化资源 key；非空即启用（ADR 0013）
     */
    public record ConfigRow(
            String id,
            String scopeId,
            String configKey,
            String configValue,
            String valueI18nKey,
            String valueType,
            boolean secret,
            String status,
            String description,
            int sortNo,
            LocalDateTime createdAt,
            LocalDateTime updatedAt) {}

    /**
     * @param dictNameKey 引用的国际化资源 key；非空即启用引用式国际化（ADR 0014）
     */
    public record DictTypeRow(
            String id,
            String scopeId,
            String dictCode,
            String dictName,
            String dictNameKey,
            boolean inheritGlobal,
            int sortNo,
            String status,
            String description,
            LocalDateTime createdAt,
            LocalDateTime updatedAt) {}

    /**
     * @param labelI18n    已退役的内联多语言列（ADR 0015），只写 null
     * @param labelI18nKey 引用的国际化资源 key；非空即启用引用式国际化（ADR 0014）
     */
    public record DictItemRow(
            String id,
            String dictTypeId,
            String itemLabel,
            String itemValue,
            int sortNo,
            boolean defaultItem,
            String color,
            String extraJson,
            String status,
            String labelI18n,
            String labelI18nKey) {}
}
