package com.kaiwu.module.agent.vo;

import java.util.List;

/**
 * 一次提问的答复。
 *
 * @param degraded 非空表示本次未能完整完成；前端按 reason 出对应文案，后端不返回已翻译的句子
 */
public record AgentAnswerView(
        String answer,
        List<AgentCardView> cards,
        List<String> usedCapabilities,
        String correlationId,
        Degraded degraded,
        AgentActionView pendingAction,
        AgentRemoteActionView pendingRemoteAction,
        AgentInputFormView inputForm) {
    public AgentAnswerView(
            String answer,
            List<AgentCardView> cards,
            List<String> usedCapabilities,
            String correlationId,
            Degraded degraded,
            AgentActionView pendingAction,
            AgentRemoteActionView pendingRemoteAction) {
        this(answer, cards, usedCapabilities, correlationId, degraded, pendingAction, pendingRemoteAction, null);
    }

    public AgentAnswerView(
            String answer,
            List<AgentCardView> cards,
            List<String> usedCapabilities,
            String correlationId,
            Degraded degraded,
            AgentActionView pendingAction) {
        this(answer, cards, usedCapabilities, correlationId, degraded, pendingAction, null);
    }

    public AgentAnswerView(
            String answer,
            List<AgentCardView> cards,
            List<String> usedCapabilities,
            String correlationId,
            Degraded degraded) {
        this(answer, cards, usedCapabilities, correlationId, degraded, null, null);
    }

    /**
     * @param reason PROVIDER_UNAVAILABLE / RATE_LIMITED / PLAN_INVALID / PARTIAL_CAPABILITY_FAILURE
     */
    public record Degraded(String reason, Integer retryAfterSeconds) {}
}
