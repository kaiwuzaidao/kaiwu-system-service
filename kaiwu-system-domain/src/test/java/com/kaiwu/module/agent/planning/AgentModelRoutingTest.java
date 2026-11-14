package com.kaiwu.module.agent.planning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.kaiwu.port.AgentAiPort;
import java.math.BigDecimal;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

/** 确保模型目标在单次任务内固定，而凭据在发起调用时读取。 */
class AgentModelRoutingTest {
    private final AgentAiPort ai = mock(AgentAiPort.class);
    private final AgentPlanner planner = new AgentPlanner(ai, new ObjectMapper());

    /** 构造包含不同绑定身份、模型和凭据的测试配置。 */
    private static AgentAiPort.RoutedConfig route(String id, String model, String key) {
        return new AgentAiPort.RoutedConfig(
                id, new AgentAiPort.RuntimeConfig("provider", "https://example.org", key, model, BigDecimal.ONE, 30));
    }

    /** 模型按用途隔离，密钥轮换后发起调用必须使用新密钥。 */
    @Test
    void targetsAreSeparateAndKeyRotationIsReadAtCallTime() {
        AtomicReference<AgentAiPort.RoutedConfig> plan = new AtomicReference<>(route("1", "small", "old"));
        when(ai.effectiveFor("PLAN")).thenAnswer(ignored -> Optional.of(plan.get()));
        when(ai.effectiveFor("ANSWER")).thenReturn(Optional.of(route("2", "large", "answer-key")));
        when(ai.chat(any(), anyString(), anyString(), anyInt()))
                .thenReturn(new AgentAiPort.ChatOutcome("{\"understood\":true,\"calls\":[]}", 1L, 1L));
        var target = planner.requireProvider("PLAN");
        var answer = planner.requireProvider("ANSWER");
        assertThat(target.toString()).doesNotContain("old");
        assertThat(answer.model()).isEqualTo("large");
        plan.set(route("1", "small", "new"));
        planner.plan(target, "system", "question");
        verify(ai)
                .chat(
                        argThat(config -> config.model().equals("small")
                                && config.apiKey().equals("new")),
                        anyString(),
                        anyString(),
                        anyInt());
    }

    /** 目标或绑定变更、配置不可用及密钥撤销都不得发出模型请求。 */
    @Test
    void changedBindingOrRevokedKeyCannotSendRequest() {
        AtomicReference<AgentAiPort.RoutedConfig> selected = new AtomicReference<>(route("1", "small", "key"));
        when(ai.effectiveFor("PLAN")).thenAnswer(ignored -> Optional.ofNullable(selected.get()));
        var target = planner.requireProvider("PLAN");
        selected.set(route("2", "small", "key"));
        assertThatThrownBy(() -> planner.plan(target, "system", "question")).isInstanceOf(IllegalStateException.class);
        selected.set(route("1", "other-model", "key"));
        assertThatThrownBy(() -> planner.plan(target, "system", "question")).isInstanceOf(IllegalStateException.class);
        selected.set(new AgentAiPort.RoutedConfig(
                "1",
                new AgentAiPort.RuntimeConfig(
                        "provider", "https://other.example.org", "key", "small", BigDecimal.ONE, 30)));
        assertThatThrownBy(() -> planner.plan(target, "system", "question")).isInstanceOf(IllegalStateException.class);
        selected.set(route("1", "small", null));
        assertThatThrownBy(() -> planner.plan(target, "system", "question")).isInstanceOf(IllegalStateException.class);
        selected.set(null);
        assertThatThrownBy(() -> planner.plan(target, "system", "question")).isInstanceOf(IllegalStateException.class);
        verify(ai, never()).chat(any(), anyString(), anyString(), anyInt());
    }

    /** 支持原本就不要求密钥的模型服务。 */
    @Test
    void initiallyUnauthenticatedProviderCanRemainUnauthenticated() {
        when(ai.effectiveFor("PLAN")).thenReturn(Optional.of(route("1", "local", null)));
        when(ai.chat(any(), anyString(), anyString(), anyInt()))
                .thenReturn(new AgentAiPort.ChatOutcome("{\"understood\":true,\"calls\":[]}", 0L, 0L));
        planner.plan(planner.requireProvider("PLAN"), "system", "question");
        verify(ai).chat(argThat(config -> config.apiKey() == null), anyString(), anyString(), anyInt());
    }
}
