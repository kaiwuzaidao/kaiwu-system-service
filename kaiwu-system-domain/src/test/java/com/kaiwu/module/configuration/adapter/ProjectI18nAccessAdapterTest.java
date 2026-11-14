package com.kaiwu.module.configuration.adapter;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.kaiwu.module.project.repository.ProjectRepository;
import com.kaiwu.module.project.vo.ProjectView;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** 项目级国际化只认目标项目的有效 project-admin；内置项目与停用项目一律拒绝。 */
class ProjectI18nAccessAdapterTest {

    private ProjectRepository repository;
    private ProjectI18nAccessAdapter adapter;

    @BeforeEach
    void setUp() {
        repository = mock(ProjectRepository.class);
        adapter = new ProjectI18nAccessAdapter(repository);
    }

    @Test
    void activeProjectAdminPasses() {
        project(false, "ACTIVE");
        when(repository.activeMemberExists("7", "u1")).thenReturn(true);
        when(repository.findCurrentRoleCodes("7", "u1")).thenReturn(Set.of("project-admin"));

        assertThatCode(() -> adapter.requireProjectAdmin("7", "u1")).doesNotThrowAnyException();
    }

    @Test
    void memberWithoutAdminRoleIsForbidden() {
        project(false, "ACTIVE");
        when(repository.activeMemberExists("7", "u1")).thenReturn(true);
        when(repository.findCurrentRoleCodes("7", "u1")).thenReturn(Set.of("project-member"));

        assertThatThrownBy(() -> adapter.requireProjectAdmin("7", "u1")).hasMessageContaining("项目管理员");
    }

    @Test
    void builtInProjectIsRejectedBecauseItsCopyIsPlatformScoped() {
        project(true, "ACTIVE");

        assertThatThrownBy(() -> adapter.requireProjectAdmin("1", "u1")).hasMessageContaining("平台资源");
    }

    @Test
    void inactiveProjectIsRejected() {
        project(false, "DISABLED");

        assertThatThrownBy(() -> adapter.requireProjectAdmin("7", "u1")).hasMessageContaining("未启用");
    }

    private void project(boolean builtIn, String status) {
        when(repository.findProject(org.mockito.ArgumentMatchers.anyString()))
                .thenReturn(Optional.of(new ProjectView(
                        "7", "p", "P", null, status, builtIn, "1", "x", null, null, "main", null, null, null, null,
                        null)));
    }
}
