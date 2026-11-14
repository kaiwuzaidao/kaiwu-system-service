package com.kaiwu.agent;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.agent.service.AgentService;
import com.kaiwu.module.agent.vo.AgentAnswerView;
import com.kaiwu.port.AgentAiPort;
import com.kaiwu.starter.KaiwuContext;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/**
 * 端到端冒烟：真实 Spring 上下文 + 真实 MySQL/Redis，只把模型出口换成可控桩。
 *
 * <p>为什么 mock 的是 {@link AgentAiPort} 而不是接真模型：这一档要验证的是上下文能否
 * 装配、编排能否跑通、能力能否真的查到库，而不是模型答得准不准。真实准确率要靠
 * ADR 0030 第 12 条的评估事件与人工标注，那是上线后的事。桩还能精确复现异常分支。</p>
 *
 * <p>默认跳过：它需要外部 MySQL 与 Redis。本地按
 * {@code docs/LOCAL-DEVELOPMENT.md} 起好依赖后，设 {@code AGENT_SMOKE=1} 运行。</p>
 */
@SpringBootTest
@ActiveProfiles("local")
@EnabledIfEnvironmentVariable(named = "AGENT_SMOKE", matches = "1")
class AgentContextSmokeTest {

    @Autowired
    private AgentService agentService;

    @Autowired
    private CapabilityCatalog catalog;

    @MockitoBean
    private AgentAiPort ai;

    private static KaiwuContext admin() {
        return new KaiwuContext(
                "9000000000000002001",
                "smoke-session",
                null,
                null,
                Set.of("system:project:list", "system:project-factory:list", "system:scheduler:list"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(600),
                "smoke-context");
    }

    /** 上下文能装配起来，能力目录按预期注册。 */
    @Test
    void contextLoadsAndCatalogIsRegistered() {
        assertThat(agentService).isNotNull();
        assertThat(catalog.size()).isEqualTo(4);
        assertThat(catalog.visibleTo(admin())).hasSize(3);
    }

    /** 全链路：规划 → 校验 → 执行（真的查库）→ 投影 → 总结。 */
    @Test
    void fullRoundTripReachesTheDatabase() {
        when(ai.effectiveConfig())
                .thenReturn(Optional.of(
                        new AgentAiPort.RuntimeConfig("stub", "http://stub", "k", "stub-model", BigDecimal.ONE, 30)));
        when(ai.chat(any(), anyString(), anyString(), anyInt()))
                .thenReturn(new AgentAiPort.ChatOutcome(
                        "{\"understood\":true,\"calls\":[{\"code\":\"system.project.list\",\"params\":{}}]}", 10L, 5L))
                .thenReturn(new AgentAiPort.ChatOutcome("已查到平台项目。", 20L, 8L));

        AgentAnswerView view = agentService.ask("平台上有哪些项目", admin(), new RequestMetadata("127.0.0.1", "smoke-test"));

        assertThat(view.correlationId()).isNotBlank();
        assertThat(view.usedCapabilities()).containsExactly(CapabilityCatalog.PROJECT_LIST);
        assertThat(view.degraded()).isNull();
        // 真实库里至少有内置 system 项目，说明查询确实落到了数据库。
        assertThat(view.cards()).hasSize(1);
        assertThat(view.cards().get(0).rows()).isNotEmpty();
    }
}
