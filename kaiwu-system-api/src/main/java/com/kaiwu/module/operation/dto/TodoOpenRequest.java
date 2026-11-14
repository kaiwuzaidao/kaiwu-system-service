package com.kaiwu.module.operation.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDateTime;

/**
 * 业务服务向 System 打开（新建或重新打开）一条待办的请求（ADR 0034）。
 *
 * <p>幂等键是 {@code (projectCode, bizKey, recipientUserId)}：同一个键重复投递只会更新标题、正文、
 * 链接与截止时间，已关闭的待办会被重新打开。打开只允许面向 {@code projectCode} 对应项目的有效成员，
 * 防止任一业务服务向平台全体用户灌入待办。
 *
 * @param projectCode 来源项目编码
 * @param bizKey 业务唯一键，由业务服务自行约定，如 {@code approval:2026-0001}；同一事项的多位处理人共用同一个键
 * @param recipientUserId 处理人的平台用户 ID
 * @param title 标题
 * @param content 正文，可空
 * @param linkUrl 点击跳转的平台内路径，可空；缺省时由 System 补成 {@code /workspace/{项目ID}}
 * @param dueAt 截止时间，可空；与 System 使用同一时区的本地时间
 */
public record TodoOpenRequest(
        @NotBlank(message = "来源项目编码不能为空") @Size(max = 64, message = "项目编码过长") String projectCode,
        @NotBlank(message = "业务键不能为空")
                @Size(max = 128, message = "业务键不能超过 128 个字符")
                @Pattern(regexp = "^[A-Za-z0-9][A-Za-z0-9:_./#-]*$", message = "业务键只能包含字母、数字与 : _ . / # -")
                String bizKey,
        @NotBlank(message = "处理人不能为空") @Size(max = 32, message = "处理人 ID 格式错误") String recipientUserId,
        @NotBlank(message = "标题不能为空") @Size(max = 200, message = "标题不能超过 200 字") String title,
        @Size(max = 2000, message = "正文不能超过 2000 字") String content,
        @Size(max = 512, message = "链接过长")
                @Pattern(
                        regexp = "^/(?!/)(?!.*\\\\)(?!.*%(?:2[fF]|5[cC]|25))[^\\r\\n]*$",
                        message = "链接必须是平台内以单个 / 开头的安全路径")
                String linkUrl,
        LocalDateTime dueAt) {}
