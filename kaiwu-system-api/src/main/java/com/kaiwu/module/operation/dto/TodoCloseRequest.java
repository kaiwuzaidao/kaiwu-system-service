package com.kaiwu.module.operation.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 业务服务关闭待办的请求（ADR 0034）。
 *
 * <p>关闭是幂等的：目标待办已关闭或不存在时不报错，业务服务可以放心重试。
 * {@code recipientUserId} 决定关闭范围——不传表示该业务键下所有处理人的待办一并关闭（或签），
 * 传了只关闭该人的待办（会签）。
 *
 * @param projectCode 来源项目编码
 * @param bizKey 业务唯一键，与打开时一致
 * @param recipientUserId 只关闭该处理人的待办；为空则关闭该业务键下所有处理人的待办
 * @param result 关闭结果：{@code DONE} 办理完成（缺省）或 {@code CANCELLED} 事项取消
 */
public record TodoCloseRequest(
        @NotBlank(message = "来源项目编码不能为空") @Size(max = 64, message = "项目编码过长") String projectCode,
        @NotBlank(message = "业务键不能为空") @Size(max = 128, message = "业务键不能超过 128 个字符") String bizKey,
        @Size(max = 32, message = "处理人 ID 格式错误") String recipientUserId,
        @Pattern(regexp = "^(DONE|CANCELLED)$", message = "关闭结果只能是 DONE 或 CANCELLED") String result) {}
