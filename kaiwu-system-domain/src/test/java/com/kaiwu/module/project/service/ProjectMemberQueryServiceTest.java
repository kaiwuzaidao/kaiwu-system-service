package com.kaiwu.module.project.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.project.model.ProjectServiceCredential;
import com.kaiwu.module.project.repository.ProjectMemberQueryRepository;
import com.kaiwu.module.project.service.impl.ProjectMemberQueryServiceImpl;
import java.util.List;
import org.junit.jupiter.api.Test;

/** 成员查询只接受凭据绑定项目且不得截断候选结果。 */
class ProjectMemberQueryServiceTest {
    /** 超限、项目不匹配、用户去重及非成员资格有明确结果。 */
    @Test
    void enforcesProjectLimitAndEligibility() {
        var credentials = mock(ProjectServiceCredentials.class);
        var repository = mock(ProjectMemberQueryRepository.class);
        var service = new ProjectMemberQueryServiceImpl(credentials, repository, 2);
        when(credentials.authenticateScopeBearer("Bearer test", "member:read"))
                .thenReturn(new ProjectServiceCredential("1", "10", "workflow"));
        when(repository.matchesProject("10", "sample")).thenReturn(true);
        when(repository.activeRole("10", "approver")).thenReturn(true);
        when(repository.membersByRole("10", "approver", 3)).thenReturn(List.of("1", "2", "3"));
        assertThatThrownBy(() -> service.byRole("Bearer test", "sample", "approver"))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        ex -> assertThat(ex.getStatus().value()).isEqualTo(422));
        assertThatThrownBy(() -> service.byRole("Bearer test", "other", "approver"))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        ex -> assertThat(ex.getStatus().value()).isEqualTo(403));
        when(repository.eligibleMembers("10", List.of("1", "2"), null)).thenReturn(List.of("1"));
        assertThat(service.eligibility("Bearer test", "sample", List.of("1", "2"), null)
                        .items())
                .extracting("eligible")
                .containsExactly(true, false);
        assertThatThrownBy(() -> service.eligibility("Bearer test", "sample", List.of("9999999999999999999"), null))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        ex -> assertThat(ex.getStatus().value()).isEqualTo(400));
    }
    /** 200是协议硬上限，不能通过配置让服务返回客户端必定拒绝的更大候选集。 */
    @Test
    void configurationCannotRaiseTheTwoHundredMemberLimit() {
        assertThatThrownBy(() -> new ProjectMemberQueryServiceImpl(
                        mock(ProjectServiceCredentials.class), mock(ProjectMemberQueryRepository.class), 201))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
