package com.kaiwu.module.project.adapter;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.project.mapper.ProjectMapper;
import com.kaiwu.module.project.service.ProjectDataScopeService;
import com.kaiwu.module.project.vo.DataScopeView;
import com.kaiwu.module.project.vo.ProjectAccessView;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.http.HttpStatus;

/**
 * 入口授权的三跳：项目 ACTIVE、成员 ACTIVE、项目内权限。
 *
 * <p>任何一跳不满足都返回空，而不是"空权限的通行证"——后者会把成员关系问题
 * 伪装成权限配置问题，排查时容易查错方向。</p>
 */
class GatewayProjectAccessServiceTest {

    private final ProjectMapper mapper = Mockito.mock(ProjectMapper.class);
    private final ProjectDataScopeService dataScopeService = Mockito.mock(ProjectDataScopeService.class);
    private final GatewayProjectAccessService service = new GatewayProjectAccessService(mapper, dataScopeService);

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

    /** 默认情况下项目没有受控资源，数据范围服务返回空。 */
    @BeforeEach
    void noDataScopeByDefault() {
        when(dataScopeService.snapshot(Mockito.anyString(), Mockito.anyString()))
                .thenReturn(Optional.empty());
    }

    /** 项目有受控资源时，入口授权快照携带数据范围。 */
    @Test
    void attachesTheDataScopeWhenTheProjectHasControlledResources() {
        DataScopeView scope = new DataScopeView(1, "101", List.of(), Map.of(), "0123456789abcdef");
        when(mapper.findActiveProjectIdByCode("order-center")).thenReturn("9000000000000001001");
        when(mapper.countActiveMember("9000000000000001001", "10001")).thenReturn(1);
        when(dataScopeService.snapshot("9000000000000001001", "10001")).thenReturn(Optional.of(scope));

        assertThat(service.resolve("order-center", "10001"))
                .hasValueSatisfying(view -> assertThat(view.dataScope()).isSameAs(scope));
    }

    /** 非成员被拒绝时不会去解析数据范围。 */
    @Test
    void doesNotResolveTheDataScopeForANonMember() {
        when(mapper.findActiveProjectIdByCode("order-center")).thenReturn("9000000000000001001");
        when(mapper.countActiveMember("9000000000000001001", "10001")).thenReturn(0);

        assertThat(service.resolve("order-center", "10001")).isEmpty();
        verify(dataScopeService, never()).snapshot(Mockito.anyString(), Mockito.anyString());
    }

    /** 数据范围超限时按拒绝处理，异常原样抛出而不是截断。 */
    @Test
    void anOversizedDataScopeDeniesInsteadOfBeingTruncated() {
        when(mapper.findActiveProjectIdByCode("order-center")).thenReturn("9000000000000001001");
        when(mapper.countActiveMember("9000000000000001001", "10001")).thenReturn(1);
        when(dataScopeService.snapshot("9000000000000001001", "10001"))
                .thenThrow(new ApiException(HttpStatus.FORBIDDEN, "数据范围过大", "api.project.dataScopeTooLarge"));

        assertThatThrownBy(() -> service.resolve("order-center", "10001"))
                .isInstanceOfSatisfying(
                        ApiException.class, e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.FORBIDDEN));
    }
}
