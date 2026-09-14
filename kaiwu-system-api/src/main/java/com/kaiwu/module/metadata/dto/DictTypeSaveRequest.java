package com.kaiwu.module.metadata.dto;

import jakarta.validation.constraints.*;

public record DictTypeSaveRequest(
        String id,
        @NotBlank(message = "字典编码不能为空") @Pattern(regexp = "[A-Za-z][A-Za-z0-9_.:-]{1,127}", message = "字典编码格式不正确")
                String dictCode,
        @NotBlank(message = "字典名称不能为空") @Size(max = 128, message = "字典名称不能超过 128 个字符") String dictName,
        /** 引用的国际化资源 key；非空即启用引用式国际化（ADR 0014）。 */
        @Size(max = 160, message = "国际化资源 key 不能超过 160 个字符") String dictNameKey,
        @NotNull(message = "继承设置不能为空") Boolean inheritGlobal,
        @NotBlank(message = "状态不能为空") @Pattern(regexp = "ENABLED|DISABLED", message = "状态非法") String status,
        @Size(max = 512, message = "说明不能超过 512 个字符") String description) {}
