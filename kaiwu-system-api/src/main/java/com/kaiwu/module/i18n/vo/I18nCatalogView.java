package com.kaiwu.module.i18n.vo;

import java.util.Map;

/** 当前语言的不可变 catalog 快照。 */
public record I18nCatalogView(String locale, long revision, Map<String, String> messages) {
    public I18nCatalogView {
        messages = Map.copyOf(messages);
    }
}
