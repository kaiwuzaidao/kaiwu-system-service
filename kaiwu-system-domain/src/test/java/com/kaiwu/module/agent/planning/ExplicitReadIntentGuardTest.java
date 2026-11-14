package com.kaiwu.module.agent.planning;

import static org.assertj.core.api.Assertions.assertThat;

import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.DataScope;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;

class ExplicitReadIntentGuardTest {
    private final CapabilityCatalog catalog = new CapabilityCatalog();

    private static KaiwuContext actorWith(String... permissions) {
        return new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of(permissions),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }

    @Test
    void deniesNamedUnavailableResourceWithoutExposingItsCode() {
        var visible = catalog.visibleTo(actorWith("system:project:list"));
        assertThat(ExplicitReadIntentGuard.denied("请查询登录日志", visible)).isTrue();
        assertThat(ExplicitReadIntentGuard.denied("查询项目生成记录", visible)).isTrue();
        assertThat(ExplicitReadIntentGuard.denied("查看生成任务详情", visible)).isTrue();
        assertThat(ExplicitReadIntentGuard.denied("查看 AI 服务配置状态", visible)).isTrue();
        assertThat(ExplicitReadIntentGuard.denied("查询国际化资源列表", visible)).isTrue();
        assertThat(ExplicitReadIntentGuard.denied("查询项目菜单", visible)).isTrue();
        assertThat(ExplicitReadIntentGuard.denied("查询参数配置详情", visible)).isTrue();
        assertThat(ExplicitReadIntentGuard.denied("查询项目列表", visible)).isFalse();
    }

    @Test
    void allowsAvailableAndAmbiguousRequestsToFollowNormalPlanning() {
        var visible = catalog.visibleTo(actorWith("system:audit:list", "system:scheduler:list"));
        assertThat(ExplicitReadIntentGuard.denied("查看登录日志", visible)).isFalse();
        assertThat(ExplicitReadIntentGuard.denied("查看所有项目的定时任务列表", visible)).isFalse();
        assertThat(ExplicitReadIntentGuard.denied("聊聊登录日志怎么设计", visible)).isFalse();
        assertThat(ExplicitReadIntentGuard.denied("帮我查点东西", visible)).isFalse();
        assertThat(ExplicitReadIntentGuard.denied("查询参数配置详情", catalog.visibleTo(actorWith("system:config:list"))))
                .isFalse();
    }

    @Test
    void businessProjectResourcesAreLeftToCatalogPruning() {
        var visible = catalog.visibleTo(actorWith("system:project:list"));
        assertThat(ExplicitReadIntentGuard.denied("查看订单列表", visible)).isFalse();
        assertThat(ExplicitReadIntentGuard.denied("查询客户详情", visible)).isFalse();
    }

    @Test
    void listApprovalDoesNotGrantDetailAccess() {
        Capability list = capability("system.config.list", "参数配置列表");
        assertThat(ExplicitReadIntentGuard.denied("查看参数配置详情", List.of(list))).isTrue();
        assertThat(ExplicitReadIntentGuard.denied("查看平台参数配置", List.of(list))).isFalse();
    }

    @Test
    void detailRequestWithIdStillRequiresDetailCapability() {
        Capability list = capability("system.config.list", "参数配置列表");
        Capability detail = capability("system.config.detail", "参数配置详情");

        assertThat(ExplicitReadIntentGuard.denied("查看参数配置 1 的详情", List.of(list)))
                .isTrue();
        assertThat(ExplicitReadIntentGuard.denied("查看参数配置编号 1 的详细信息", List.of(list)))
                .isTrue();
        assertThat(ExplicitReadIntentGuard.denied("查看参数配置 1 的详情", List.of(list, detail)))
                .isFalse();
        assertThat(ExplicitReadIntentGuard.denied("查看参数配置 1 的详情", List.of(detail)))
                .isFalse();
        assertThat(ExplicitReadIntentGuard.denied("查看平台参数配置列表", List.of(list))).isFalse();
        assertThat(ExplicitReadIntentGuard.denied("查看平台参数配置列表和参数配置 1 的详情", List.of(detail)))
                .isTrue();
    }

    private static Capability capability(String code, String description) {
        return new Capability(
                "system",
                code,
                "1",
                description,
                "system:config:list",
                DataScope.MEMBER_PROJECTS,
                Map.of(),
                Set.of("id"),
                Map.of(),
                true,
                false,
                true);
    }
}
