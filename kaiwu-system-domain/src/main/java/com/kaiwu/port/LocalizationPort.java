package com.kaiwu.port;

/** 认证模块读取语言可用性与菜单文案的边界。 */
public interface LocalizationPort {

    boolean selectableLocale(String locale);

    TextResolver resolver(String locale, boolean anonymous);

    @FunctionalInterface
    interface TextResolver {
        String of(String key, String fallback);
    }
}
