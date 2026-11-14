package com.kaiwu.module.agent.presentation;

import java.time.Instant;
import java.util.List;
import java.util.Map;

/**
 * 送浏览器渲染的投影。
 *
 * <p>走用户自己的浏览器，不经过外部 Provider，因此**可以**包含 outboundFields
 * 之外的本地导航字段；远程 Handler 的结果仍须经过审核字段白名单与脱敏，不能信任远程自报输出。</p>
 *
 * <p>{@code sourceProjects} 与行内的 {@code sourceProjectId} 是内部字段，前端可以
 * 不展示，但不得省略存储：一张卡片聚合了 A、B 两个项目的行之后，没有行级来源，
 * P1b 读取历史时无法判断用户失去 B 权限后该隐藏哪些行（ADR 0030 第 15 条）。</p>
 *
 * @param dataAt 查询时刻，界面据此提示数据时间
 */
public record CardProjection(
        CardType type, String title, List<Map<String, Object>> rows, List<String> sourceProjects, Instant dataAt) {

    /** 行内保留来源项目的键名，供历史重授权逐行过滤。 */
    public static final String SOURCE_PROJECT_ID = "sourceProjectId";

    public CardProjection {
        rows = rows == null ? List.of() : List.copyOf(rows);
        sourceProjects = sourceProjects == null ? List.of() : List.copyOf(sourceProjects);
    }

    public enum CardType {
        /** 单个数字，如「待处理 248」。 */
        METRIC,
        /** 列表结果。 */
        TABLE,
        /** 查到零条。 */
        EMPTY
    }
}
