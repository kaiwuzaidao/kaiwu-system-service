package com.kaiwu.module.metadata.dto;

import jakarta.validation.constraints.*;

public record DictItemSaveRequest(
        String id,
        @NotBlank(message = "字典标签不能为空") @Size(max = 128, message = "字典标签不能超过 128 个字符") String itemLabel,
        @NotBlank(message = "字典值不能为空") @Size(max = 128, message = "字典值不能超过 128 个字符") String itemValue,
        @NotNull(message = "排序不能为空") @Min(value = 0, message = "排序不能小于 0") @Max(value = 9999, message = "排序不能大于 9999")
                Integer sortNo,
        @NotNull(message = "默认项标识不能为空") Boolean defaultItem,
        @Size(max = 32, message = "颜色不能超过 32 个字符") String color,
        String extraJson,
        /**
         * 引用的国际化资源 key。多语言只走这条路（ADR 0015），
         * 为空即「独立填写」，只有 itemLabel 一种语言。
         */
        @Size(max = 160, message = "国际化资源 key 不能超过 160 个字符") String labelI18nKey,
        @NotBlank(message = "状态不能为空") @Pattern(regexp = "ENABLED|DISABLED", message = "状态非法") String status) {}
