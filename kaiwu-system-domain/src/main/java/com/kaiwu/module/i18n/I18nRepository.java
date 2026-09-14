package com.kaiwu.module.i18n;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.kaiwu.module.i18n.entity.I18nMessageEntity;
import com.kaiwu.module.i18n.entity.TranslationExportJoinRow;
import com.kaiwu.module.i18n.mapper.I18nMapper;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Repository;
import org.springframework.util.StringUtils;

@Repository
public class I18nRepository {

    private final I18nMapper mapper;

    private final Clock clock;

    public I18nRepository(I18nMapper mapper, Clock clock) {
        this.mapper = mapper;
        this.clock = clock;
    }

    /**
     * 国际化资源列表。
     *
     * @param enabledOnly 只取 ENABLED，运行期下发用
     * @param publicOnly  只取允许匿名下发的，登录页在未登录时用
     */
    public List<MessageRow> messages(boolean enabledOnly, boolean publicOnly) {
        LambdaQueryWrapper<I18nMessageEntity> query = new LambdaQueryWrapper<I18nMessageEntity>()
                .eq(enabledOnly, I18nMessageEntity::getStatus, "ENABLED")
                .eq(publicOnly, I18nMessageEntity::getPublicVisible, true)
                .orderByAsc(I18nMessageEntity::getModuleCode)
                .orderByAsc(I18nMessageEntity::getMessageKey);
        return mapper.selectList(query).stream().map(I18nRepository::toRow).toList();
    }

    public Optional<MessageRow> message(String id) {
        return Optional.ofNullable(mapper.selectById(Long.parseLong(id))).map(I18nRepository::toRow);
    }

    /** 资源 key 是否已存在；{@code excludedId} 在编辑时传自身以排除。 */
    public boolean keyExists(String key, String excludedId) {
        LambdaQueryWrapper<I18nMessageEntity> query =
                new LambdaQueryWrapper<I18nMessageEntity>().eq(I18nMessageEntity::getMessageKey, key);
        if (StringUtils.hasText(excludedId)) {
            query.ne(I18nMessageEntity::getId, Long.parseLong(excludedId));
        }
        return mapper.exists(query);
    }

    /** 新建资源；版本号从 1 起，后续每次更新 +1，用于乐观锁判冲突。 */
    public void insert(MessageRow row) {
        I18nMessageEntity entity = new I18nMessageEntity();
        entity.setId(Long.parseLong(row.id()));
        entity.setMessageKey(row.messageKey());
        entity.setDefaultText(row.defaultText());
        entity.setTranslationsJson(row.translationsJson());
        entity.setModuleCode(row.moduleCode());
        entity.setPublicVisible(row.publicVisible());
        entity.setRequiredResource(row.requiredResource());
        entity.setStatus(row.status());
        entity.setDescription(row.description());
        // 新建资源的版本从 1 起，后续每次更新 +1，用于乐观锁。
        entity.setVersion(1L);
        LocalDateTime now = LocalDateTime.now(clock);
        entity.setCreatedAt(now);
        entity.setUpdatedAt(now);
        mapper.insert(entity);
    }

    /** @return 是否更新成功；false 表示版本已被他人改动 */
    public boolean update(MessageRow row, long expectedVersion) {
        return mapper.updateWithVersion(
                        Long.parseLong(row.id()),
                        row.messageKey(),
                        row.defaultText(),
                        row.translationsJson(),
                        row.moduleCode(),
                        row.publicVisible(),
                        row.requiredResource(),
                        row.status(),
                        row.description(),
                        expectedVersion)
                == 1;
    }

    public boolean delete(String id, long expectedVersion) {
        return mapper.deleteWithVersion(Long.parseLong(id), expectedVersion) == 1;
    }

    public long revision() {
        Long revision = mapper.revision();
        return revision == null ? 1 : revision;
    }

    public void bumpRevision() {
        mapper.bumpRevision();
    }

    public List<String> enabledLocales() {
        return mapper.enabledLocales();
    }

    /** 平台已启用的语言列表，来自全局字典 {@code platform.locale}。 */
    public List<LocaleRow> locales() {
        return mapper.locales().stream()
                .map(row -> new LocaleRow(
                        row.getItemValue(),
                        row.getItemLabel(),
                        row.getLabelI18nKey(),
                        row.getExtraJson(),
                        Boolean.TRUE.equals(row.getDefaultItem())))
                .toList();
    }

    /**
     * 该语言下缺译文的必需资源条数；用于判断一门语言能否开放选择。
     *
     * @param defaultLocale 默认语言用 default_text，本就无需译文，等于它时直接返回 0
     */
    public long missingRequiredResources(String locale, String defaultLocale) {
        // 默认语言用 default_text，本就无需译文；这里必须跟随默认语言，
        // 写死 zh-CN 会在默认语言改成别的语言后让豁免对象和判定对象错位。
        if (defaultLocale.equalsIgnoreCase(locale)) return 0;
        return zeroIfNull(mapper.missingRequiredResources(locale));
    }

    public long missingMenus(String locale, String defaultLocale) {
        if (defaultLocale.equalsIgnoreCase(locale)) return 0;
        return zeroIfNull(mapper.missingMenus());
    }

    public long missingDictionaryItems(String locale, String defaultLocale) {
        if (defaultLocale.equalsIgnoreCase(locale)) return 0;
        return zeroIfNull(mapper.missingDictionaryItems(locale));
    }

    // ---- 译文批量导出/导入 ----
    // 导出与覆盖率校验必须用同一套筛选条件，否则会出现"导出表填满了，
    // 语言仍显示未开放"的死循环。

    public List<TranslationExportRow> exportResources(String locale) {
        return mapper.exportResources(locale).stream()
                .map(I18nRepository::toExport)
                .toList();
    }

    public List<TranslationExportRow> exportMenus() {
        return mapper.exportMenus().stream().map(I18nRepository::toExport).toList();
    }

    public List<TranslationExportRow> exportDictionaryItems(String locale) {
        return mapper.exportDictionaryItems(locale).stream()
                .map(I18nRepository::toExport)
                .toList();
    }

    public int upsertResourceTranslation(String key, String locale, String translation) {
        return mapper.upsertResourceTranslation(key, locale, translation);
    }

    public int upsertMenuTranslation(String routePath, String locale, String translation) {
        return mapper.upsertMenuTranslation(routePath, locale, translation);
    }

    /** @param key 形如 {@code dictCode:itemValue} */
    public int upsertDictionaryTranslation(String key, String locale, String translation) {
        int separator = key.lastIndexOf(':');
        if (separator <= 0 || separator == key.length() - 1) return 0;
        String dictCode = key.substring(0, separator);
        String itemValue = key.substring(separator + 1);
        return mapper.upsertDictionaryTranslation(dictCode, itemValue, locale, translation);
    }

    private static long zeroIfNull(Long value) {
        return value == null ? 0 : value;
    }

    private static TranslationExportRow toExport(TranslationExportJoinRow row) {
        return new TranslationExportRow(row.getExportKey(), row.getDefaultText(), row.getTranslation(), row.getNote());
    }

    private static MessageRow toRow(I18nMessageEntity entity) {
        return new MessageRow(
                String.valueOf(entity.getId()),
                entity.getMessageKey(),
                entity.getDefaultText(),
                entity.getTranslationsJson(),
                entity.getModuleCode(),
                Boolean.TRUE.equals(entity.getPublicVisible()),
                Boolean.TRUE.equals(entity.getRequiredResource()),
                entity.getStatus(),
                entity.getDescription(),
                entity.getVersion() == null ? 0 : entity.getVersion(),
                entity.getUpdatedAt());
    }

    public record TranslationExportRow(String key, String defaultText, String translation, String description) {}

    public record MessageRow(
            String id,
            String messageKey,
            String defaultText,
            String translationsJson,
            String moduleCode,
            boolean publicVisible,
            boolean requiredResource,
            String status,
            String description,
            long version,
            LocalDateTime updatedAt) {}

    /**
     * @param labelKey 语言名引用的国际化资源 key（ADR 0015 后语言名译文也走资源目录）
     */
    public record LocaleRow(String locale, String label, String labelKey, String extraJson, boolean defaultLocale) {}
}
