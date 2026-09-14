package com.kaiwu.module.org;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.audit.AuditService;
import com.kaiwu.module.org.dto.DepartmentSaveRequest;
import com.kaiwu.module.org.dto.UserDepartmentRequest;
import com.kaiwu.module.org.vo.DepartmentView;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class OrgServiceTest {

    private OrgRepository repository;
    private AuditService auditService;
    private OrgService service;
    private KaiwuContext actor;

    @BeforeEach
    void setUp() {
        repository = mock(OrgRepository.class);
        auditService = mock(AuditService.class);
        service = new OrgService(repository, auditService);
        actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:org:save"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }

    @Test
    void updateDepartmentRejectsItselfAsParent() {
        when(repository.findDepartment("10")).thenReturn(Optional.of(department("10", null)));

        assertThatThrownBy(() -> service.saveDepartment(
                        new DepartmentSaveRequest("10", "10", "研发部", "rd", 10, "ENABLED"),
                        actor,
                        new RequestMetadata("127.0.0.1", "trace-1")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("上级部门");

        verify(repository, never()).saveDepartment("10", "10", "研发部", "rd", 10, "ENABLED");
    }

    @Test
    void assignDepartmentsRejectsUnknownIds() {
        when(repository.userExists("2")).thenReturn(true);
        when(repository.countDepartments(Set.of("10", "11"))).thenReturn(1);

        assertThatThrownBy(() -> service.assignDepartments(
                        "2",
                        new UserDepartmentRequest(List.of("10", "11")),
                        actor,
                        new RequestMetadata("127.0.0.1", "trace-1")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("不存在");
    }

    @Test
    void deletingDepartmentWithChildrenFailsClosed() {
        when(repository.findDepartment("10")).thenReturn(Optional.of(department("10", null)));
        when(repository.childCount("10")).thenReturn(1);

        assertThatThrownBy(() -> service.deleteDepartment("10", actor, new RequestMetadata("127.0.0.1", "trace-1")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("下级部门");
    }

    @Test
    void batchUserDepartmentsIncludesUnassignedUsersAndPreservesPrimaryOrder() {
        when(repository.userDepartmentIdsByUsers(List.of("2", "3"))).thenReturn(Map.of("2", List.of("10", "11")));

        Map<String, List<String>> result = service.userDepartments(List.of("2", "3"));

        assertThat(result).containsEntry("2", List.of("10", "11")).containsEntry("3", List.of());
    }

    @Test
    void batchUserDepartmentsRejectsMoreThanOneHundredUsers() {
        List<String> userIds = java.util.stream.IntStream.rangeClosed(1, 101)
                .mapToObj(String::valueOf)
                .toList();

        assertThatThrownBy(() -> service.userDepartments(userIds))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("100");
    }

    private static DepartmentView department(String id, String parentId) {
        LocalDateTime now = LocalDateTime.now();
        return new DepartmentView(id, parentId, "研发部", "rd", 10, "ENABLED", now, now, List.of());
    }
}
