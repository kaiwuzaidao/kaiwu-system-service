package com.kaiwu.module.identity.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.org.dto.DepartmentSaveRequest;
import com.kaiwu.module.org.dto.UserDepartmentRequest;
import com.kaiwu.module.org.vo.DepartmentView;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;
import java.util.Map;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface OrgService {

    List<DepartmentView> departments();

    DepartmentView department(String id);

    DepartmentView saveDepartment(DepartmentSaveRequest request, KaiwuContext actor, RequestMetadata metadata);

    DepartmentView renameDepartment(
            String id,
            String newName,
            DepartmentRenameExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    DepartmentView updateDepartmentStatus(
            String id,
            String status,
            DepartmentRenameExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    void deleteDepartment(String id, KaiwuContext actor, RequestMetadata metadata);

    DepartmentView previewDepartmentDeletion(String id);

    void deleteDepartmentForAgent(
            String id, DepartmentDeleteExpectation expected, KaiwuContext actor, RequestMetadata metadata);

    List<String> userDepartments(String userId);

    Map<String, List<String>> userDepartments(List<String> userIds);

    List<String> assignDepartments(
            String userId, UserDepartmentRequest request, KaiwuContext actor, RequestMetadata metadata);

    /** 在一个事务内追加成员，保留已有主部门与兼任部门。 */
    int addDepartmentMembers(String departmentId, List<String> userIds, KaiwuContext actor, RequestMetadata metadata);

    List<String> previewUserDepartmentAssignment(String userId, List<String> departmentIds);

    void assignDepartmentsForAgent(
            String userId,
            List<String> departmentIds,
            List<String> expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    public record DepartmentRenameExpectation(String name, String code, String parentId, String status) {}

    public record DepartmentDeleteExpectation(String name, String code, String parentId, int sortNo, String status) {}
}
