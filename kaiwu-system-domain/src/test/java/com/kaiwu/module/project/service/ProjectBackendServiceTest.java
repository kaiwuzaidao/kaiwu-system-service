package com.kaiwu.module.project.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.repository.ProjectBackendServiceRepository;
import com.kaiwu.module.project.repository.ProjectRepository;
import com.kaiwu.module.project.service.impl.ProjectBackendServiceImpl;
import com.kaiwu.module.project.vo.BackendServiceView;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;

/** 校验项目后端服务的授权、地址和可发布片段约束。 */
class ProjectBackendServiceTest {
    /** 非管理员、关闭开关、非法上游和 disabled 服务均不能形成有效新路由。 */
    @Test
    void enforcesProjectAdminAndSafeRoute() {
        var services = mock(ProjectBackendServiceRepository.class);
        var projects = mock(ProjectRepository.class);
        var audit = mock(AuditPort.class);
        var actor = mock(KaiwuContext.class);
        var metadata = mock(RequestMetadata.class);
        var project = mock(ProjectView.class);
        when(project.projectCode()).thenReturn("demo");
        when(projects.findProject("1")).thenReturn(Optional.of(project));
        when(actor.userId()).thenReturn("2");
        when(projects.activeMemberExists("1", "2")).thenReturn(true);
        when(projects.findCurrentRoleCodes("1", "2")).thenReturn(Set.of("project-admin"));
        when(services.lockProject("1")).thenReturn(true);
        when(services.find("1", "default")).thenReturn(Optional.of(new BackendServiceView("default", null, "ENABLED")));
        var enabled = new ProjectBackendServiceImpl(services, projects, audit, true);
        for (String url :
                List.of("file:///etc/passwd", "http://user:pass@host", "http://host/private", "http://host/?x=1"))
            assertThatThrownBy(() -> enabled.create("1", "workflow", url, actor, metadata))
                    .isInstanceOf(ApiException.class);
        var disabled = new ProjectBackendServiceImpl(services, projects, audit, false);
        assertThatThrownBy(() -> disabled.create("1", "workflow", "http://localhost:8080", actor, metadata))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        ex -> assertThat(ex.getStatus().value()).isEqualTo(503));
        when(services.find("1", "workflow"))
                .thenReturn(Optional.of(new BackendServiceView("workflow", "http://localhost:8080", "ENABLED")));
        assertThat(enabled.create("1", "workflow", "http://localhost:8080", actor, metadata)
                        .serviceCode())
                .isEqualTo("workflow");
        verify(audit)
                .recordOperationInCallerTransaction(
                        eq(actor), eq("project"), eq("CREATE_BACKEND_SERVICE"), anyString(), anyString(), eq(metadata));
        when(services.list("1"))
                .thenReturn(List.of(
                        new BackendServiceView("workflow", "http://localhost:8080", "ENABLED"),
                        new BackendServiceView("archived", "http://localhost:8081", "DISABLED")));
        assertThat(enabled.routes("1", actor).fragments()).singleElement().satisfies(fragment -> assertThat(
                        fragment.fragment())
                .contains(
                        "id: demo.workflow-project",
                        "Path=/demo-svc/workflow/**",
                        "audience: kaiwu-demo.workflow-service"));
        when(services.find("1", "default")).thenReturn(Optional.empty());
        assertThatThrownBy(() -> enabled.routes("1", actor))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        ex -> assertThat(ex.getStatus().value()).isEqualTo(503));
        assertThat(disabled.routes("1", actor).fragments()).isEmpty();
        when(projects.findCurrentRoleCodes("1", "2")).thenReturn(Set.of("viewer"));
        assertThatThrownBy(() -> enabled.list("1", actor)).isInstanceOfSatisfying(ApiException.class, ex -> assertThat(
                        ex.getStatus().value())
                .isEqualTo(403));
    }
    /** 混合版本关闭期间，旧实例只改service_url后默认片段仍须保持旧接口行为，不能依赖滞后的回填行。 */
    @Test
    void disabledMultiModeRendersDefaultFromTheLegacyAuthority() {
        var services = mock(ProjectBackendServiceRepository.class);
        var projects = mock(ProjectRepository.class);
        var actor = mock(KaiwuContext.class);
        var project = mock(ProjectView.class);
        when(actor.userId()).thenReturn("2");
        when(project.projectCode()).thenReturn("demo");
        when(project.projectName()).thenReturn("Demo");
        when(project.serviceUrl()).thenReturn("http://new-default:8080");
        when(projects.findProject("1")).thenReturn(Optional.of(project));
        when(projects.activeMemberExists("1", "2")).thenReturn(true);
        when(projects.findCurrentRoleCodes("1", "2")).thenReturn(Set.of("project-admin"));
        when(services.list("1"))
                .thenReturn(List.of(
                        new BackendServiceView("default", null, "ENABLED"),
                        new BackendServiceView("workflow", "http://workflow:8080", "ENABLED")));
        var service = new ProjectBackendServiceImpl(services, projects, mock(AuditPort.class), false);
        assertThat(service.routes("1", actor).fragments()).singleElement().satisfies(fragment -> assertThat(
                        fragment.fragment())
                .contains("uri: http://new-default:8080", "Path=/demo-api/**", "audience: kaiwu-demo-service")
                .doesNotContain("demo-svc"));
    }
    /** 项目名称虽可包含换行，也只能进入YAML注释，不能注入额外路由条目。 */
    @Test
    void projectDisplayNameCannotInjectRouteYaml() {
        var project = mock(ProjectView.class);
        when(project.projectName()).thenReturn("Demo\n- id: injected\n  uri: http://other");
        when(project.projectCode()).thenReturn("demo");
        when(project.serviceUrl()).thenReturn("http://default:8080");
        String fragment = com.kaiwu.module.project.model.GatewayRouteFragment.render(project);
        Object loaded = new org.yaml.snakeyaml.Yaml().load(fragment);
        assertThat((List<?>) loaded).hasSize(1);
    }
}
