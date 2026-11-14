package com.kaiwu.module.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * CLI 发起设备授权的请求（ADR 0035）。
 *
 * <p>客户端名称只用于在确认页和在线会话列表展示，不参与任何授权判断；限制字符集是为了
 * 确认页上不出现可伪装成系统提示的文本。</p>
 */
public record DeviceAuthorizationStartRequest(
        @NotBlank(message = "客户端名称不能为空")
                @Size(max = 64, message = "客户端名称不能超过64个字符")
                @Pattern(regexp = "[\\p{L}\\p{N} ._()-]+", message = "客户端名称只能包含文字、数字、空格和 ._()-")
                String clientName) {}
