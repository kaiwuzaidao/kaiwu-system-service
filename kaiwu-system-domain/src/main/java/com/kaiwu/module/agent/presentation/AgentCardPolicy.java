package com.kaiwu.module.agent.presentation;

import java.util.Locale;

/** Keeps optional result cards out of responses when they are only evidence for a decision. */
public final class AgentCardPolicy {

    private AgentCardPolicy() {}

    public static boolean showDetails(String question) {
        if (question == null || question.isBlank()) {
            return true;
        }
        String text = question.replaceAll("\\s+", "").toLowerCase(Locale.ROOT);
        boolean summaryOnly = containsAny(text, "只回复", "仅回复", "只返回", "仅返回", "只告诉", "仅告诉", "只看", "只要")
                && containsAny(text, "条数", "数量", "总数", "统计", "汇总", "是否", "结果", "count");
        boolean rejectDetails = containsAny(text, "不展示", "不显示", "不要展示", "不要显示", "不列出", "不要列出", "别展示", "无需展示", "无须展示")
                && containsAny(text, "详情", "明细", "列表", "表格", "记录", "用户标识", "用户id", "用户编号");
        boolean requestsDetails = containsAny(text, "列表", "明细", "详情", "表格", "卡片", "逐条", "列出");
        boolean decisionOnly = !requestsDetails
                && ((containsAny(text, "检查", "判断", "核对") && containsAny(text, "能否", "可否", "是否可以", "是否能"))
                        || containsAny(text, "不要执行", "不执行", "只检查", "仅检查"));
        return !summaryOnly && !rejectDetails && !decisionOnly;
    }

    private static boolean containsAny(String text, String... fragments) {
        for (String fragment : fragments) {
            if (text.contains(fragment)) {
                return true;
            }
        }
        return false;
    }
}
