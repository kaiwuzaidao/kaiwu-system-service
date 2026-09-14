package com.kaiwu.module.project;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.module.project.mapper.ProjectMapper;
import com.kaiwu.module.project.vo.ProjectAccessView;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

/**
 * 入口授权的三跳：项目 ACTIVE、成员 ACTIVE、项目内权限。
 *
 * <p>任何一跳不满足都返回空，而不是"空权限的通行证"——后者会把成员关系问题
 * 伪装成权限配置问题，排查时容易查错方向。</p>
 */
class GatewayProjectAccessServiceTest {

    private final ProjectMapper mapper = Mockito.mock(ProjectMapper.class);
    private final GatewayProjectAccessService service = new GatewayProjectAccessService(mapper);

    @Test
    void resolvesProjectFactsForActiveMember() {
        when(mapper.findActiveProjectIdByCode("order-center")).thenReturn("9000000000000001001");
        when(mapper.countActiveMember("9000000000000001001", "10001")).thenReturn(1);
        when(mapper.findCurrentPermissions("9000000000000001001", "10001")).thenReturn(List.of("order:order:list"));
        when(mapper.findMemberRoleCodes("9000000000000001001", "10001")).thenReturn(List.of("project-admin"));

        Optional<ProjectAccessView> access = service.resolve("order-center", "10001");

        assertThat(access).hasValueSatisfying(view -> {
            assertThat(view.projectId()).isEqualTo("9000000000000001001");
            assertThat(view.projectCode()).isEqualTo("order-center");
            assertThat(view.permissions()).containsExactly("order:order:list");
            assertThat(view.projectRoleCodes()).containsExactly("project-admin");
        });
    }

    /** 项目不是 ACTIVE：停用或归档的项目不该再有外部入口，而且不必再查成员。 */
    @Test
    void deniesWhenProjectIsNotActive() {
        when(mapper.findActiveProjectIdByCode("order-center")).thenReturn(null);

        assertThat(service.resolve("order-center", "10001")).isEmpty();
        verify(mapper, never()).countActiveMember(Mockito.anyString(), Mockito.anyString());
    }

    /** 不是 ACTIVE 成员：拒绝入口，而不是返回空权限。 */
    @Test
    void deniesWhenMemberIsNotActive() {
        when(mapper.findActiveProjectIdByCode("order-center")).thenReturn("9000000000000001001");
        when(mapper.countActiveMember("9000000000000001001", "10001")).thenReturn(0);

        assertThat(service.resolve("order-center", "10001")).isEmpty();
        verify(mapper, never()).findCurrentPermissions(Mockito.anyString(), Mockito.anyString());
    }
}
