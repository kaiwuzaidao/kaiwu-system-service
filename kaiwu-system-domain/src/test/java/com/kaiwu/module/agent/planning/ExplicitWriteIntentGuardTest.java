package com.kaiwu.module.agent.planning;

import static org.assertj.core.api.Assertions.assertThat;

import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.util.Set;
import org.junit.jupiter.api.Test;

class ExplicitWriteIntentGuardTest {
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
    void deniesExplicitUnavailableWritesBeforePlanning() {
        var visible = catalog.visibleTo(actorWith("system:project:list"));
        assertThat(ExplicitWriteIntentGuard.denied("帮我创建项目", visible)).isTrue();
        assertThat(ExplicitWriteIntentGuard.denied("帮我创建项目角色", visible)).isTrue();
        assertThat(ExplicitWriteIntentGuard.denied("修改项目角色名称", visible)).isTrue();
        assertThat(ExplicitWriteIntentGuard.denied("删除项目角色", visible)).isTrue();
        assertThat(ExplicitWriteIntentGuard.denied("停用项目角色", visible)).isTrue();
        assertThat(ExplicitWriteIntentGuard.denied("给项目角色分配菜单权限", visible)).isTrue();
        assertThat(ExplicitWriteIntentGuard.denied("停用项目菜单", visible)).isTrue();
        assertThat(ExplicitWriteIntentGuard.denied("删除项目菜单", visible)).isTrue();
        assertThat(ExplicitWriteIntentGuard.denied("创建一个字典", visible)).isTrue();
        assertThat(ExplicitWriteIntentGuard.denied("删除字典类型", visible)).isTrue();
        assertThat(ExplicitWriteIntentGuard.denied("添加字典项", visible)).isTrue();
        assertThat(ExplicitWriteIntentGuard.denied("创建部门", visible)).isTrue();
        assertThat(ExplicitWriteIntentGuard.denied("创建新用户", visible)).isTrue();
        assertThat(ExplicitWriteIntentGuard.denied("停用用户 35", visible)).isTrue();
    }

    @Test
    void allowsVisibleOrAmbiguousRequestsToFollowNormalPlanning() {
        var visible = catalog.visibleTo(actorWith("system:project:create"));
        assertThat(ExplicitWriteIntentGuard.denied("帮我创建项目", visible)).isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("创建项目角色", catalog.visibleTo(actorWith("system:project:role"))))
                .isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("修改项目角色名称", catalog.visibleTo(actorWith("system:project:role"))))
                .isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("删除项目角色", catalog.visibleTo(actorWith("system:project:role"))))
                .isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("停用项目角色", catalog.visibleTo(actorWith("system:project:role"))))
                .isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("给项目角色分配菜单权限", catalog.visibleTo(actorWith("system:project:role"))))
                .isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("停用项目菜单", catalog.visibleTo(actorWith("system:project:menu"))))
                .isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("删除项目菜单", catalog.visibleTo(actorWith("system:project:menu"))))
                .isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("删除字典类型", catalog.visibleTo(actorWith("system:dict:delete"))))
                .isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("创建一个字典", catalog.visibleTo(actorWith("system:dict:save"))))
                .isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("添加字典项", catalog.visibleTo(actorWith("system:dict:save"))))
                .isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("创建部门", catalog.visibleTo(actorWith("system:org:save"))))
                .isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("创建新用户", catalog.visibleTo(actorWith("system:user:create"))))
                .isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("停用用户 35", catalog.visibleTo(actorWith("system:user:status"))))
                .isFalse();
        assertThat(ExplicitWriteIntentGuard.denied("如何创建项目？", visible)).isFalse();
    }
}
