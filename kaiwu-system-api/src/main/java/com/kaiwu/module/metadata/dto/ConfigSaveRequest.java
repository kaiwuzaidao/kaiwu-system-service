package com.kaiwu.module.metadata.dto;

import jakarta.validation.constraints.*;

public record ConfigSaveRequest(
        String id,
        @NotBlank(message = "配置键不能为空") @Pattern(regexp = "[A-Za-z][A-Za-z0-9_.:-]{1,127}", message = "配置键格式不正确")
                String configKey,
        String configValue,
        /**
         * 展示型配置引用的国际化资源 key；为空表示不启用国际化。
         * 界面上「启用国际化」勾选框由它是否为空推导，不额外存布尔开关。
         */
        @Size(max = 160, message = "国际化资源 key 不能超过 160 个字符") String valueI18nKey,
        @NotBlank(message = "值类型不能为空") @Pattern(regexp = "STRING|NUMBER|BOOLEAN|JSON", message = "值类型非法")
                String valueType,
        @NotNull(message = "敏感标识不能为空") Boolean secret,
        @NotBlank(message = "状态不能为空") @Pattern(regexp = "ENABLED|DISABLED", message = "状态非法") String status,
        @Size(max = 512, message = "说明不能超过 512 个字符") String description,
        @NotNull(message = "排序不能为空") @Min(value = 0, message = "排序不能小于 0") @Max(value = 9999, message = "排序不能大于 9999")
                Integer sortNo) {}
