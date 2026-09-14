package com.kaiwu.module.projectgeneration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.project.ProjectRepository;
import com.kaiwu.module.project.vo.ProjectView;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;

class ProjectFactoryAccessServiceTest {

    @Test
    void rejectsBuiltInSystemProject() {
        ProjectRepository repository = mock(ProjectRepository.class);
        when(repository.findProject("system")).thenReturn(Optional.of(project("system", true, "ACTIVE")));

        assertThatThrownBy(() -> new ProjectFactoryAccessService(repository).requireProjectAdmin("system", "user-1"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("system");
    }

    @Test
    void requiresActiveProjectAdminMembership() {
        ProjectRepository repository = mock(ProjectRepository.class);
        when(repository.findProject("project-1")).thenReturn(Optional.of(project("project-1", false, "ACTIVE")));
        when(repository.activeMemberExists("project-1", "user-1")).thenReturn(true);
        when(repository.findCurrentRoleCodes("project-1", "user-1")).thenReturn(Set.of("developer"));

        assertThatThrownBy(() -> new ProjectFactoryAccessService(repository).requireProjectAdmin("project-1", "user-1"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("项目管理员");

        when(repository.findCurrentRoleCodes("project-1", "user-1")).thenReturn(Set.of("project-admin"));
        assertThat(new ProjectFactoryAccessService(repository)
                        .requireProjectAdmin("project-1", "user-1")
                        .id())
                .isEqualTo("project-1");
    }

    private ProjectView project(String id, boolean builtIn, String status) {
        LocalDateTime now = LocalDateTime.now();
        return new ProjectView(
                id,
                builtIn ? "system" : "order-center",
                builtIn ? "系统平台" : "订单中心",
                "后台",
                status,
                builtIn,
                "1",
                "com.example.order",
                null,
                null,
                "main",
                null,
                null,
                null,
                now,
                now);
    }
}
