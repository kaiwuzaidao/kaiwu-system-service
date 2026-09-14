package com.kaiwu.module.i18n;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.LocaleCode;
import com.kaiwu.module.i18n.I18nRepository.MessageRow;
import com.kaiwu.module.i18n.vo.I18nCatalogView;
import com.kaiwu.module.i18n.vo.I18nLocaleView;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

/** 国际化目录读取、语言开放状态和目录缓存。 */
@Component
final class I18nCatalogService {

    private static final String FALLBACK_LOCALE = "zh-CN";
    private static final int MAX_CACHE_ENTRIES = 64;

    private final I18nRepository repository;
    private final ObjectMapper objectMapper;
    private final Map<CatalogCacheKey, I18nCatalogView> catalogCache = new ConcurrentHashMap<>();

    I18nCatalogService(I18nRepository repository, ObjectMapper objectMapper) {
        this.repository = repository;
        this.objectMapper = objectMapper;
    }

    String defaultLocale() {
        return repository.locales().stream()
                .filter(row -> LocaleCode.isValid(row.locale()))
                .filter(I18nRepository.LocaleRow::defaultLocale)
                .map(I18nRepository.LocaleRow::locale)
                .findFirst()
                .orElse(FALLBACK_LOCALE);
    }

    I18nCatalogView catalog(String locale, boolean publicOnly) {
        String normalized = requireEnabledLocale(locale);
        long revision = repository.revision();
        CatalogCacheKey cacheKey = new CatalogCacheKey(normalized, publicOnly, revision);
        I18nCatalogView cached = catalogCache.get(cacheKey);
        if (cached != null) return cached;

        Map<String, String> messages = new LinkedHashMap<>();
        String defaultLocale = defaultLocale();
        for (MessageRow row : repository.messages(true, publicOnly)) {
            String text = localizedText(row, normalized, defaultLocale);
            if (StringUtils.hasText(text)) messages.put(row.messageKey(), text);
        }
        I18nCatalogView result = new I18nCatalogView(normalized, revision, messages);
        if (catalogCache.size() >= MAX_CACHE_ENTRIES) catalogCache.clear();
        catalogCache.put(cacheKey, result);
        return result;
    }

    boolean messageKeyExists(String messageKey) {
        return StringUtils.hasText(messageKey) && repository.keyExists(messageKey, null);
    }

    List<I18nLocaleView> locales(String displayLocale) {
        String normalizedDisplayLocale = requireEnabledLocale(displayLocale);
        String defaultLocale = defaultLocale();
        return repository.locales().stream()
                .filter(row -> LocaleCode.isValid(row.locale()))
                .map(row -> localeView(row, normalizedDisplayLocale, defaultLocale))
                .toList();
    }

    boolean selectableLocale(String locale) {
        if (!LocaleCode.isValid(locale)) return false;
        return selectableLocales().stream().anyMatch(item -> item.equalsIgnoreCase(locale));
    }

    List<String> selectableLocales() {
        return locales(defaultLocale()).stream()
                .filter(I18nLocaleView::selectable)
                .map(I18nLocaleView::locale)
                .toList();
    }

    String requireTranslatableLocale(String locale) {
        String normalized = requireEnabledLocale(locale);
        if (defaultLocale().equalsIgnoreCase(normalized)) {
            throw error(HttpStatus.BAD_REQUEST, "默认语言使用原文，无需导入译文", "api.i18n.defaultLocaleNotTranslatable");
        }
        return normalized;
    }

    void invalidate() {
        catalogCache.clear();
    }

    private I18nLocaleView localeView(I18nRepository.LocaleRow row, String displayLocale, String defaultLocale) {
        boolean configured = configuredSelectable(row.extraJson());
        long missingResources = repository.missingRequiredResources(row.locale(), defaultLocale);
        long missingMenus = repository.missingMenus(row.locale(), defaultLocale);
        long missingDictionaryItems = repository.missingDictionaryItems(row.locale(), defaultLocale);
        boolean complete = missingResources == 0 && missingMenus == 0 && missingDictionaryItems == 0;
        return new I18nLocaleView(
                row.locale(),
                localizedLabel(row, displayLocale, defaultLocale),
                configured,
                configured && complete,
                missingResources,
                missingMenus,
                missingDictionaryItems);
    }

    private String localizedLabel(I18nRepository.LocaleRow row, String locale, String defaultLocale) {
        if (defaultLocale.equals(locale) || !StringUtils.hasText(row.labelKey())) return row.label();
        String text = catalog(locale, false).messages().get(row.labelKey());
        return StringUtils.hasText(text) ? text : row.label();
    }

    private String requireEnabledLocale(String locale) {
        String requested = StringUtils.hasText(locale) ? locale.trim() : defaultLocale();
        if (!LocaleCode.isValid(requested)) {
            throw error(HttpStatus.BAD_REQUEST, "暂不支持该语言", "api.locale.unsupported");
        }
        return repository.enabledLocales().stream()
                .filter(LocaleCode::isValid)
                .filter(item -> item.equalsIgnoreCase(requested))
                .findFirst()
                .orElseThrow(() -> error(HttpStatus.BAD_REQUEST, "暂不支持该语言", "api.locale.unsupported"));
    }

    private String localizedText(MessageRow row, String locale, String defaultLocale) {
        if (defaultLocale.equals(locale)) return row.defaultText();
        if (!StringUtils.hasText(row.translationsJson())) return null;
        try {
            Map<String, String> translations =
                    objectMapper.readValue(row.translationsJson(), new TypeReference<Map<String, String>>() {});
            return translations.get(locale);
        } catch (Exception ignored) {
            return null;
        }
    }

    private boolean configuredSelectable(String json) {
        if (!StringUtils.hasText(json)) return false;
        try {
            Map<String, Object> value = objectMapper.readValue(json, new TypeReference<Map<String, Object>>() {});
            return Boolean.TRUE.equals(value.get("selectable"));
        } catch (Exception ignored) {
            return false;
        }
    }

    private static ApiException error(HttpStatus status, String message, String key) {
        return new ApiException(status, message, key);
    }

    private record CatalogCacheKey(String locale, boolean publicOnly, long revision) {}
}
