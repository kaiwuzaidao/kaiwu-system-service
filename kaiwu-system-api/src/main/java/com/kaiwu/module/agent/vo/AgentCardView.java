package com.kaiwu.module.agent.vo;

import java.time.Instant;
import java.util.List;
import java.util.Map;

/**
 * 一张结果卡片。
 *
 * @param dataAt 查询时刻；界面据此提示数据时间，避免用户拿过期数据做判断
 */
public record AgentCardView(
        String type,
        String capabilityCode,
        String title,
        List<Map<String, Object>> rows,
        Instant dataAt,
        OutputView outputView,
        Navigation navigation) {
    public AgentCardView(
            String type,
            String capabilityCode,
            String title,
            List<Map<String, Object>> rows,
            Instant dataAt,
            OutputView outputView) {
        this(type, capabilityCode, title, rows, dataAt, outputView, null);
    }
    /** Buttons contain validated input, never URLs. Every click re-enters normal authorization. */
    public record Command(String label, String capabilityCode, Map<String, Object> values) {}

    public record RowCommand(int rowIndex, Command command) {}

    public record Navigation(Integer page, Command previous, Command next, List<RowCommand> details) {}

    /** Optional, approved display hints; never supplied by the model or execution response. */
    public record OutputView(String title, List<Field> fields) {}

    public record Field(String name, String label, String format, String dictCode) {}
}
