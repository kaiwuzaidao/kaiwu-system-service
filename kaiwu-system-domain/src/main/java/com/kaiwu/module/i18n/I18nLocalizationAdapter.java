package com.kaiwu.module.i18n;

import com.kaiwu.port.LocalizationPort;
import org.springframework.stereotype.Component;

/** 将国际化目录适配为认证模块所需的最小能力。 */
@Component
public class I18nLocalizationAdapter implements LocalizationPort {

    private final I18nService service;

    public I18nLocalizationAdapter(I18nService service) {
        this.service = service;
    }

    @Override
    public boolean selectableLocale(String locale) {
        return service.selectableLocale(locale);
    }

    @Override
    public TextResolver resolver(String locale, boolean anonymous) {
        I18nService.LocalizedText localized = service.resolver(locale, anonymous);
        return localized::of;
    }
}
