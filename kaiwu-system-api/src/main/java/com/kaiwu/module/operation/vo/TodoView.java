package com.kaiwu.module.operation.vo;

import java.time.LocalDateTime;

/**
 * 待办视图；19 位 ID 在 JSON 契约中保持字符串。
 *
 * <p>业务键属于来源服务的内部约定，不对终端用户暴露。{@code overdue} 由服务端按当前时间计算，
 * 客户端不自行判断，避免各端时区与时钟偏差造成不一致。
 *
 * @param id 待办 ID
 * @param projectId 来源项目 ID
 * @param projectCode 来源项目编码
 * @param title 标题
 * @param content 正文，可空
 * @param linkUrl 点击跳转的平台内路径
 * @param status 状态：OPEN、DONE 或 CANCELLED
 * @param dueAt 截止时间，可空
 * @param overdue 是否已逾期：仅 OPEN 且设置了截止时间并已过期时为 true
 * @param openedAt 打开（或重新打开）时间
 * @param closedAt 关闭时间，未关闭为空
 */
public record TodoView(
        String id,
        String projectId,
        String projectCode,
        String title,
        String content,
        String linkUrl,
        String status,
        LocalDateTime dueAt,
        boolean overdue,
        LocalDateTime openedAt,
        LocalDateTime closedAt) {}
