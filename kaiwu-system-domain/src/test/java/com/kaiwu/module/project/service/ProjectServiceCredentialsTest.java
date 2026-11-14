package com.kaiwu.module.project.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.port.ProjectCredentialStorePort;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.security.crypto.password.PasswordEncoder;

/** 验证旧凭据能力与受限服务凭据的隔离。 */
class ProjectServiceCredentialsTest {
    /** 非关键使用时间更新失败时，已通过凭据验证的调用仍可继续。 */
    @Test
    void usageWriteFailureDoesNotRejectValidCredential() {
        var store = mock(ProjectCredentialStorePort.class);
        var encoder = mock(PasswordEncoder.class);
        when(store.findActive("1"))
                .thenReturn(Optional.of(
                        new ProjectCredentialStorePort.StoredCredential("1", "p1", "hash", "default", Set.of())));
        when(encoder.matches("zsch_1_secret", "hash")).thenReturn(true);
        Mockito.doThrow(new IllegalStateException("database unavailable"))
                .when(store)
                .touchLastUsed("1");
        assertThat(new ProjectServiceCredentials(store, encoder)
                        .authenticate("zsch_1_secret")
                        .projectId())
                .isEqualTo("p1");
    }

    /** 旧入口与显式 scope 入口不得互相继承权限。 */
    @Test
    void legacyEntrancesAndScopedEntrancesCannotBorrowEachOthersPermissions() {
        var store = mock(ProjectCredentialStorePort.class);
        var encoder = mock(PasswordEncoder.class);
        var credentials = new ProjectServiceCredentials(store, encoder);
        when(store.findActive("1"))
                .thenReturn(Optional.of(new ProjectCredentialStorePort.StoredCredential(
                        "1", "project-a", "hash", "default", Set.of())));
        when(store.findActive("2"))
                .thenReturn(Optional.of(new ProjectCredentialStorePort.StoredCredential(
                        "2", "project-a", "hash", "workflow", Set.of("member:read"))));
        when(encoder.matches("zsch_1_secret", "hash")).thenReturn(true);
        when(encoder.matches("zsch_2_secret", "hash")).thenReturn(true);

        assertThat(credentials.authenticate("zsch_1_secret").projectId()).isEqualTo("project-a");
        assertThatThrownBy(() -> credentials.authenticate("zsch_2_secret")).isInstanceOf(ApiException.class);
        assertThat(credentials
                        .authenticateScoped("zsch_2_secret", "project-a", "member:read")
                        .id())
                .isEqualTo("2");
        assertThatThrownBy(() -> credentials.authenticateScoped("zsch_1_secret", "project-a", "member:read"))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> credentials.authenticateScoped("zsch_2_secret", "project-b", "member:read"))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> credentials.authenticateScoped("zsch_2_secret", "project-a", "todo:managed"))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> credentials.authenticateScoped("zsch_2_wrong", "project-a", "member:read"))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> credentials.authenticate("shared-delivery-token"))
                .isInstanceOf(ApiException.class);
    }
}
