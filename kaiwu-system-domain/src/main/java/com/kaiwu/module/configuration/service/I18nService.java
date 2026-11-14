package com.kaiwu.module.configuration.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.i18n.dto.I18nMessageSaveRequest;
import com.kaiwu.module.i18n.vo.I18nCatalogView;
import com.kaiwu.module.i18n.vo.I18nLocaleView;
import com.kaiwu.module.i18n.vo.I18nMessageView;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;
import java.util.Map;
import org.springframework.util.StringUtils;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface I18nService {

    String defaultLocale();

    List<I18nMessageView> messages();

    I18nCatalogView catalog(String locale, boolean publicOnly);

    boolean messageKeyExists(String messageKey);

    /**
     * 按作用域判断 key 是否可引用（ADR 0037）。
     *
     * @param scopeId "0" 为平台，只查平台资源；项目 ID 时项目或平台存在即可
     */
    boolean messageKeyExists(String scopeId, String messageKey);

    /**
     * 按作用域取解析器（ADR 0037）：平台作用域等同 {@link #resolver(String, boolean)}，
     * 项目作用域先查项目资源再回退平台。
     */
    LocalizedText resolver(String scopeId, String locale, boolean anonymous);

    /** 业务项目内是否已有该 key；不看平台资源（ADR 0037）。 */
    boolean projectMessageKeyExists(String projectId, String messageKey);

    /**
     * 新建业务项目的国际化资源（ADR 0037）。项目内 key 已存在时拒绝，不覆盖人工改译；
     * 调用方负责校验调用者是该项目的项目管理员。
     */
    I18nMessageView createProjectMessage(
            String projectId, I18nMessageSaveRequest request, KaiwuContext actor, RequestMetadata metadata);

    /** 项目管理页：某业务项目的资源列表（含停用）。调用方负责先确认项目管理员身份。 */
    List<I18nMessageView> projectMessages(String projectId);

    I18nMessageView saveProjectMessage(
            String projectId, I18nMessageSaveRequest request, KaiwuContext actor, RequestMetadata metadata);

    void deleteProjectMessage(String projectId, String id, long version, KaiwuContext actor, RequestMetadata metadata);

    byte[] exportProjectTranslations(String projectId, String locale);

    TranslationImportResult importProjectTranslations(
            String projectId, String locale, byte[] bytes, KaiwuContext actor, RequestMetadata metadata);

    LocalizedText resolver(String locale, boolean anonymous);

    List<I18nLocaleView> locales(String displayLocale);

    boolean selectableLocale(String locale);

    byte[] exportTranslations(String locale);

    TranslationImportResult importTranslations(
            String locale, byte[] bytes, KaiwuContext actor, RequestMetadata metadata);

    I18nMessageView save(I18nMessageSaveRequest request, KaiwuContext actor, RequestMetadata metadata);

    void delete(String id, long version, KaiwuContext actor, RequestMetadata metadata);

    public record LocalizedText(Map<String, String> messages) {

        public LocalizedText {
            messages = messages == null ? Map.of() : Map.copyOf(messages);
        }

        public String of(String key, String fallback) {
            if (!StringUtils.hasText(key)) return fallback;
            String text = messages.get(key);
            return StringUtils.hasText(text) ? text : fallback;
        }
    }

    public record TranslationImportResult(int applied, List<String> failures) {}
}
