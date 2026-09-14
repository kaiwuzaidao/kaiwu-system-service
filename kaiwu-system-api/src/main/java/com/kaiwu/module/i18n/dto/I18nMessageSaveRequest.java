package com.kaiwu.module.i18n.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** 国际化资源保存请求；更新时 version 用于乐观锁。 */
public record I18nMessageSaveRequest(
        String id,
        @NotBlank(message = "{api.validation.required}")
                @Pattern(regexp = "[A-Za-z][A-Za-z0-9_.:-]{1,159}", message = "{api.i18n.keyInvalid}")
                String messageKey,
        @NotBlank(message = "{api.validation.required}") @Size(max = 2000, message = "{api.i18n.defaultTextTooLong}")
                String defaultText,
        String translationsJson,
        @NotBlank(message = "{api.validation.required}")
                @Pattern(regexp = "[A-Za-z][A-Za-z0-9_.:-]{1,63}", message = "{api.i18n.moduleInvalid}")
                String moduleCode,
        @NotNull(message = "{api.validation.required}") Boolean publicVisible,
        @NotNull(message = "{api.validation.required}") Boolean requiredResource,
        @NotBlank(message = "{api.validation.required}")
                @Pattern(regexp = "ENABLED|DISABLED", message = "{api.i18n.statusInvalid}")
                String status,
        @Size(max = 512, message = "{api.i18n.descriptionTooLong}") String description,
        Long version) {}
