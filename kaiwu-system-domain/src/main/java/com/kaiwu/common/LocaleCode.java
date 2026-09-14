package com.kaiwu.common;

import java.util.Locale;
import java.util.Set;

/** 规范平台 locale，拒绝看似合法但语言子标签不存在的值（例如 {@code jp}）。 */
public final class LocaleCode {

    private static final Set<String> ISO_LANGUAGES = Set.of(Locale.getISOLanguages());

    private LocaleCode() {}

    /**
     * 是否为合法的 BCP 47 语言标记（如 {@code zh-CN}）。
     *
     * <p>显式拒绝下划线写法（{@code zh_CN}）：那是 Java 老式 Locale 的格式，
     * 混进来会让前后端对同一门语言算出两个不同的 key。</p>
     */
    public static boolean isValid(String value) {
        if (value == null || value.isBlank() || value.contains("_")) return false;
        Locale locale = Locale.forLanguageTag(value);
        return !locale.getLanguage().isBlank()
                && ISO_LANGUAGES.contains(locale.getLanguage())
                && locale.toLanguageTag().equalsIgnoreCase(value);
    }
}
