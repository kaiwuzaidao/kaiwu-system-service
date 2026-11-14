package com.kaiwu.module.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.repository.OrgRepository;
import com.kaiwu.module.identity.service.OrgService.DepartmentRenameExpectation;
import com.kaiwu.module.identity.service.impl.OrgServiceImpl;
import com.kaiwu.module.operation.service.AuditService;
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
        service = new OrgServiceImpl(repository, auditService);
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
    void bulkAddPreservesPrimaryAndSkipsExistingMembers() {
        when(repository.findDepartmentForUpdate("10")).thenReturn(Optional.of(department("10", null)));
        when(repository.lockUser("1")).thenReturn(true);
        when(repository.lockUser("2")).thenReturn(true);
        when(repository.lockUser("3")).thenReturn(true);
        when(repository.userDepartmentIds("1")).thenReturn(List.of("20"));
        when(repository.userDepartmentIds("2")).thenReturn(List.of());
        when(repository.userDepartmentIds("3")).thenReturn(List.of("10"));
        assertThat(service.addDepartmentMembers(
                        "10", List.of("3", "2", "1", "1"), actor, new RequestMetadata("127.0.0.1", "trace")))
                .isEqualTo(2);
        verify(repository).replaceUserDepartments("1", List.of("20", "10"));
        verify(repository).replaceUserDepartments("2", List.of("10"));
        verify(repository, never()).replaceUserDepartments("3", List.of("10"));
    }

    @Test
    void bulkAddRejectsDepartmentLimit() {
        when(repository.findDepartmentForUpdate("10")).thenReturn(Optional.of(department("10", null)));
        when(repository.lockUser("1")).thenReturn(true);
        when(repository.userDepartmentIds("1"))
                .thenReturn(java.util.stream.IntStream.range(20, 40)
                        .mapToObj(String::valueOf)
                        .toList());
        assertThatThrownBy(() -> service.addDepartmentMembers(
                        "10", List.of("1"), actor, new RequestMetadata("127.0.0.1", "trace")))
                .isInstanceOf(ApiException.class);
        verify(repository, never())
                .replaceUserDepartments(
                        org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyList());
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
    void departmentRenamePreservesCodeParentAndSortAfterLock() {
        when(repository.findDepartmentForUpdate("10")).thenReturn(Optional.of(department("10", null)));
        var changed = new DepartmentView("10", null, "新名称", "rd", 10, "ENABLED", null, null, List.of());
        when(repository.findDepartment("10")).thenReturn(Optional.of(changed));

        var result = service.renameDepartment(
                "10",
                "新名称",
                new DepartmentRenameExpectation("研发部", "rd", "", "ENABLED"),
                actor,
                new RequestMetadata("127.0.0.1", "trace-1"));

        assertThat(result.name()).isEqualTo("新名称");
        verify(repository).saveDepartment("10", null, "新名称", "rd", 10, "ENABLED");
    }

    @Test
    void departmentRenameRejectsChangedState() {
        when(repository.findDepartmentForUpdate("10")).thenReturn(Optional.of(department("10", "20")));

        assertThatThrownBy(() -> service.renameDepartment(
                        "10",
                        "新名称",
                        new DepartmentRenameExpectation("研发部", "rd", "", "ENABLED"),
                        actor,
                        new RequestMetadata("127.0.0.1", "trace-1")))
                .hasMessageContaining("部门已变化");
        verify(repository, never()).saveDepartment("10", "20", "新名称", "rd", 10, "ENABLED");
    }

    @Test
    void departmentStatusUpdatePreservesIdentityAfterLock() {
        when(repository.findDepartmentForUpdate("10")).thenReturn(Optional.of(department("10", null)));
        var disabled = new DepartmentView("10", null, "研发部", "rd", 10, "DISABLED", null, null, List.of());
        when(repository.findDepartment("10")).thenReturn(Optional.of(disabled));

        var result = service.updateDepartmentStatus(
                "10",
                "DISABLED",
                new DepartmentRenameExpectation("研发部", "rd", "", "ENABLED"),
                actor,
                new RequestMetadata("127.0.0.1", "trace-1"));

        assertThat(result.status()).isEqualTo("DISABLED");
        verify(repository).saveDepartment("10", null, "研发部", "rd", 10, "DISABLED");
    }

    @Test
    void departmentStatusUpdateRejectsChangedPreview() {
        when(repository.findDepartmentForUpdate("10")).thenReturn(Optional.of(department("10", "20")));
        assertThatThrownBy(() -> service.updateDepartmentStatus(
                        "10",
                        "DISABLED",
                        new DepartmentRenameExpectation("研发部", "rd", "", "ENABLED"),
                        actor,
                        new RequestMetadata("127.0.0.1", "trace-1")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("部门已变化");
        verify(repository, never()).saveDepartment("10", "20", "研发部", "rd", 10, "DISABLED");
    }

    @Test
    void departmentStatusUpdateRejectsMissingStatusBeforeLookup() {
        assertThatThrownBy(() -> service.updateDepartmentStatus(
                        "10",
                        null,
                        new DepartmentRenameExpectation("研发部", "rd", "", "ENABLED"),
                        actor,
                        new RequestMetadata("127.0.0.1", "trace-1")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("部门状态不合法");
        verify(repository, never()).findDepartmentForUpdate("10");
    }

    @Test
    void assignDepartmentsRejectsUnknownIds() {
        when(repository.lockUser("2")).thenReturn(true);
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
    void agentDepartmentAssignmentRejectsChangedOrderedSnapshot() {
        when(repository.lockUser("2")).thenReturn(true);
        when(repository.userDepartmentIds("2")).thenReturn(List.of("11", "10"));
        assertThatThrownBy(() -> service.assignDepartmentsForAgent(
                        "2", List.of("10"), List.of("10", "11"), actor, new RequestMetadata("127.0.0.1", "trace-1")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已变化");
        verify(repository, never()).replaceUserDepartments("2", List.of("10"));
    }

    @Test
    void agentDepartmentAssignmentPreservesPrimaryOrderAndAudit() {
        when(repository.lockUser("2")).thenReturn(true);
        when(repository.userDepartmentIds("2")).thenReturn(List.of("10"));
        when(repository.countDepartments(Set.of("11", "12"))).thenReturn(2);
        service.assignDepartmentsForAgent(
                "2", List.of("11", "12"), List.of("10"), actor, new RequestMetadata("127.0.0.1", "trace-1"));
        verify(repository).replaceUserDepartments("2", List.of("11", "12"));
        verify(auditService)
                .recordOperation(
                        org.mockito.ArgumentMatchers.eq(actor),
                        org.mockito.ArgumentMatchers.eq("org"),
                        org.mockito.ArgumentMatchers.eq("ASSIGN_USER_DEPARTMENTS"),
                        org.mockito.ArgumentMatchers.anyString(),
                        org.mockito.ArgumentMatchers.anyString(),
                        org.mockito.ArgumentMatchers.any());
    }

    @Test
    void deletingDepartmentWithChildrenFailsClosed() {
        when(repository.findDepartmentForUpdate("10")).thenReturn(Optional.of(department("10", null)));
        when(repository.childCount("10")).thenReturn(1);

        assertThatThrownBy(() -> service.deleteDepartment("10", actor, new RequestMetadata("127.0.0.1", "trace-1")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("下级部门");
    }

    @Test
    void agentDepartmentDeleteRejectsChangedPreview() {
        when(repository.findDepartmentForUpdate("10")).thenReturn(Optional.of(department("10", null)));
        assertThatThrownBy(() -> service.deleteDepartmentForAgent(
                        "10",
                        new OrgService.DepartmentDeleteExpectation("旧名称", "rd", null, 10, "ENABLED"),
                        actor,
                        new RequestMetadata("127.0.0.1", "trace-1")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已变化");
        verify(repository, never()).deleteDepartment("10");
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
