package com.kaiwu.module.auth.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 当前登录用户修改界面语言的请求。
 *
 * @param locale IETF 风格 locale；具体支持范围由 System 白名单校验
 */
public record UpdateLocaleRequest(@NotBlank(message = "语言不能为空") String locale) {}
