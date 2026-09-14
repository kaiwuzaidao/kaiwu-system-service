package com.kaiwu.module.notification.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 业务服务向 System 投递站内信的请求（ADR 0007）。
 *
 * <p>只允许向 {@code projectCode} 对应项目的有效成员投递，防止任一业务服务
 * 向平台全体用户群发。投递是单向、只写、失败即降级的窄接口，不承载任何鉴权语义。
 */
public record NotificationSendRequest(
        @NotBlank(message = "来源项目编码不能为空") @Size(max = 64, message = "项目编码过长") String projectCode,
        @NotBlank(message = "收件人不能为空") @Size(max = 32, message = "收件人 ID 格式错误") String recipientUserId,
        @Size(max = 32, message = "消息分类过长") String notificationType,
        @NotBlank(message = "标题不能为空") @Size(max = 200, message = "标题不能超过 200 字") String title,
        @Size(max = 2000, message = "正文不能超过 2000 字") String content,
        @Size(max = 512, message = "链接过长")
                @Pattern(
                        regexp = "^/(?!/)(?!.*\\\\)(?!.*%(?:2[fF]|5[cC]|25))[^\\r\\n]*$",
                        message = "链接必须是平台内以单个 / 开头的安全路径")
                String linkUrl) {}
