package com.kaiwu.module.operation.vo;

import java.util.List;

/**
 * 待办概览：未处理数量、其中已逾期的数量与最近若干条未处理待办，供工作台使用。
 *
 * @param openCount 未处理（OPEN）待办总数
 * @param overdueCount 其中已逾期的数量
 * @param recent 最近打开的若干条未处理待办
 */
public record TodoSummaryView(long openCount, long overdueCount, List<TodoView> recent) {}
