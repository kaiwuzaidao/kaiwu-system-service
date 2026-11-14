package com.kaiwu.module.identity.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.repository.OrgRepository;
import com.kaiwu.module.identity.service.OrgService;
import com.kaiwu.module.operation.service.AuditService;
import com.kaiwu.module.org.dto.DepartmentSaveRequest;
import com.kaiwu.module.org.dto.UserDepartmentRequest;
import com.kaiwu.module.org.vo.DepartmentView;
import com.kaiwu.starter.KaiwuContext;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/** 部门树和用户部门归属。 */
@Service("orgService")
public class OrgServiceImpl implements OrgService {

    private static final AtomicLong IDS = new AtomicLong(System.currentTimeMillis() * 1_000_000L);
    private final OrgRepository repository;
    private final AuditService auditService;

    public OrgServiceImpl(OrgRepository repository, AuditService auditService) {
        this.repository = repository;
        this.auditService = auditService;
    }

    /** 部门树；库里存的是扁平行，这里按 parent_id 组装成树后返回。 */
    public List<DepartmentView> departments() {
        List<DepartmentView> rows = repository.departments();
        Map<String, DepartmentView> byId =
                rows.stream().collect(Collectors.toMap(DepartmentView::id, Function.identity()));
        return rows.stream()
                .filter(row -> !StringUtils.hasText(row.parentId()) || !byId.containsKey(row.parentId()))
                .map(row -> tree(row, rows))
                .toList();
    }

    public DepartmentView department(String id) {
        return requireDepartment(id);
    }

    /** 新增或编辑部门；编码全局唯一，父部门不能指向自己或自己的子孙。 */
    @Transactional
    public DepartmentView saveDepartment(DepartmentSaveRequest request, KaiwuContext actor, RequestMetadata metadata) {
        if (StringUtils.hasText(request.id())) {
            requireDepartment(request.id());
        }
        String id = StringUtils.hasText(request.id()) ? request.id() : nextId();
        String parentId = StringUtils.hasText(request.parentId()) ? request.parentId() : null;
        if (id.equals(parentId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "上级部门不能是当前部门", "api.common.badRequest");
        }
        if (parentId != null) {
            requireDepartment(parentId);
            requireNoCycle(id, parentId);
        }
        String code = request.code().trim();
        if (repository.codeExists(code, request.id())) {
            throw new ApiException(HttpStatus.CONFLICT, "部门编码已存在", "api.common.conflict");
        }
        repository.saveDepartment(
                id,
                parentId,
                request.name().trim(),
                code,
                request.sortNo() == null ? 0 : request.sortNo(),
                StringUtils.hasText(request.status()) ? request.status() : "ENABLED");
        auditService.recordOperation(
                actor,
                "org",
                StringUtils.hasText(request.id()) ? "UPDATE_DEPARTMENT" : "CREATE_DEPARTMENT",
                "/api/org/departments",
                "departmentId=" + id,
                metadata);
        return requireDepartment(id);
    }

    /** Rename a department without changing its code, parent, sort order or status. */
    @Transactional
    public DepartmentView renameDepartment(
            String id,
            String newName,
            DepartmentRenameExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        if (newName == null || newName.isBlank() || newName.trim().length() > 100 || expected == null)
            throw new ApiException(HttpStatus.BAD_REQUEST, "部门名称不合法", "api.common.badRequest");
        DepartmentView current = repository
                .findDepartmentForUpdate(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "部门不存在", "api.common.notFound"));
        if (!Objects.equals(current.name(), expected.name())
                || !Objects.equals(current.code(), expected.code())
                || !Objects.equals(Objects.toString(current.parentId(), ""), expected.parentId())
                || !Objects.equals(current.status(), expected.status()))
            throw new ApiException(HttpStatus.CONFLICT, "部门已变化，请重新预览", "api.common.conflict");
        String name = newName.trim();
        if (name.equals(current.name()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "部门名称没有变化", "api.common.badRequest");
        repository.saveDepartment(id, current.parentId(), name, current.code(), current.sortNo(), current.status());
        auditService.recordOperation(
                actor, "org", "UPDATE_DEPARTMENT", "/api/org/departments", "departmentId=" + id, metadata);
        return requireDepartment(id);
    }

    /** Agent status change locks and compares the frozen preview before preserving all other department fields. */
    @Transactional
    public DepartmentView updateDepartmentStatus(
            String id,
            String status,
            DepartmentRenameExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        if (status == null || !Set.of("ENABLED", "DISABLED").contains(status) || expected == null)
            throw new ApiException(HttpStatus.BAD_REQUEST, "部门状态不合法", "api.common.badRequest");
        DepartmentView current = repository
                .findDepartmentForUpdate(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "部门不存在", "api.common.notFound"));
        if (!Objects.equals(current.name(), expected.name())
                || !Objects.equals(current.code(), expected.code())
                || !Objects.equals(Objects.toString(current.parentId(), ""), expected.parentId())
                || !Objects.equals(current.status(), expected.status()))
            throw new ApiException(HttpStatus.CONFLICT, "部门已变化，请重新预览", "api.common.conflict");
        if (status.equals(current.status()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "部门状态没有变化", "api.common.badRequest");
        repository.saveDepartment(id, current.parentId(), current.name(), current.code(), current.sortNo(), status);
        auditService.recordOperation(
                actor, "org", "UPDATE_DEPARTMENT", "/api/org/departments", "departmentId=" + id, metadata);
        return requireDepartment(id);
    }

    /** 删除部门；有子部门或仍有用户归属时拒绝，避免留下孤儿节点与悬空归属。 */
    @Transactional
    public void deleteDepartment(String id, KaiwuContext actor, RequestMetadata metadata) {
        DepartmentView current = repository
                .findDepartmentForUpdate(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "部门不存在", "api.common.notFound"));
        requireDepartmentEmpty(id);
        repository.deleteDepartment(current.id());
        auditService.recordOperation(
                actor, "org", "DELETE_DEPARTMENT", "/api/org/departments/" + id, "departmentId=" + id, metadata);
    }

    /** A department can be removed only when it has no children or assigned users. */
    public DepartmentView previewDepartmentDeletion(String id) {
        DepartmentView current = requireDepartment(id);
        requireDepartmentEmpty(id);
        return current;
    }

    @Transactional
    public void deleteDepartmentForAgent(
            String id, DepartmentDeleteExpectation expected, KaiwuContext actor, RequestMetadata metadata) {
        DepartmentView current = repository
                .findDepartmentForUpdate(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "部门不存在", "api.common.notFound"));
        if (expected == null
                || !Objects.equals(current.name(), expected.name())
                || !Objects.equals(current.code(), expected.code())
                || !Objects.equals(current.parentId(), expected.parentId())
                || current.sortNo() != expected.sortNo()
                || !Objects.equals(current.status(), expected.status()))
            throw new ApiException(HttpStatus.CONFLICT, "部门已变化，请重新预览", "api.common.conflict");
        deleteDepartment(id, actor, metadata);
    }

    private void requireDepartmentEmpty(String id) {
        if (repository.childCount(id) > 0)
            throw new ApiException(HttpStatus.CONFLICT, "存在下级部门，不能删除", "api.common.conflict");
        if (repository.assignmentCount(id) > 0)
            throw new ApiException(HttpStatus.CONFLICT, "部门仍有用户归属，不能删除", "api.common.conflict");
    }

    public List<String> userDepartments(String userId) {
        requireUser(userId);
        return repository.userDepartmentIds(userId);
    }

    /** 批量查用户所属部门，供列表页一次性带出；单次上限 100 个用户。 */
    public Map<String, List<String>> userDepartments(List<String> userIds) {
        List<String> ids = new ArrayList<>(new LinkedHashSet<>(userIds));
        if (ids.size() > 100) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "单次最多查询 100 个用户的部门归属", "api.common.badRequest");
        }
        Map<String, List<String>> assigned = repository.userDepartmentIdsByUsers(ids);
        Map<String, List<String>> result = new LinkedHashMap<>();
        ids.forEach(userId -> result.put(userId, assigned.getOrDefault(userId, List.of())));
        return result;
    }

    /** 全量覆盖用户的部门归属；列表第一个即主部门。 */
    @Transactional
    public List<String> assignDepartments(
            String userId, UserDepartmentRequest request, KaiwuContext actor, RequestMetadata metadata) {
        lockUser(userId);
        List<String> ids = new ArrayList<>(
                new LinkedHashSet<>(request.departmentIds() == null ? List.of() : request.departmentIds()));
        Set<String> unique = Set.copyOf(ids);
        if (repository.countDepartments(unique) != unique.size()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "存在不存在的部门", "api.common.badRequest");
        }
        repository.replaceUserDepartments(userId, ids);
        auditService.recordOperation(
                actor,
                "org",
                "ASSIGN_USER_DEPARTMENTS",
                "/api/org/users/" + userId + "/departments",
                "targetUserId=" + userId + ", departmentCount=" + ids.size(),
                metadata);
        return ids;
    }

    /** 按稳定顺序锁定用户，追加归属并保留原有主部门；任一失败时整批回滚。 */
    @Transactional
    public int addDepartmentMembers(
            String departmentId, List<String> userIds, KaiwuContext actor, RequestMetadata metadata) {
        if (userIds == null
                || userIds.isEmpty()
                || userIds.size() > 100
                || userIds.stream().anyMatch(id -> !StringUtils.hasText(id)))
            throw new ApiException(HttpStatus.BAD_REQUEST, "用户列表不合法", "api.common.badRequest");
        if (repository.findDepartmentForUpdate(departmentId).isEmpty())
            throw new ApiException(HttpStatus.NOT_FOUND, "部门不存在", "api.common.notFound");
        int added = 0;
        for (String userId : userIds.stream().distinct().sorted().toList()) {
            lockUser(userId);
            List<String> ids = new ArrayList<>(repository.userDepartmentIds(userId));
            if (ids.contains(departmentId)) continue;
            if (ids.size() >= 20)
                throw new ApiException(HttpStatus.BAD_REQUEST, "用户最多归属 20 个部门", "api.common.badRequest");
            ids.add(departmentId);
            repository.replaceUserDepartments(userId, ids);
            added++;
        }
        auditService.recordOperation(
                actor,
                "org",
                "ADD_DEPARTMENT_MEMBERS",
                "/api/org/departments/" + departmentId + "/members",
                "departmentId=" + departmentId + ", addedCount=" + added,
                metadata);
        return added;
    }

    /** Preview the ordered full replacement; the first department remains the primary department. */
    public List<String> previewUserDepartmentAssignment(String userId, List<String> departmentIds) {
        requireUser(userId);
        validateDepartmentAssignment(departmentIds);
        List<String> current = repository.userDepartmentIds(userId);
        if (current.equals(departmentIds))
            throw new ApiException(HttpStatus.BAD_REQUEST, "用户部门归属没有变化", "api.common.badRequest");
        return current;
    }

    @Transactional
    public void assignDepartmentsForAgent(
            String userId,
            List<String> departmentIds,
            List<String> expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        lockUser(userId);
        if (expected == null || !repository.userDepartmentIds(userId).equals(expected))
            throw new ApiException(HttpStatus.CONFLICT, "用户部门归属已变化，请重新确认", "api.common.conflict");
        validateDepartmentAssignment(departmentIds);
        if (departmentIds.equals(expected))
            throw new ApiException(HttpStatus.BAD_REQUEST, "用户部门归属没有变化", "api.common.badRequest");
        assignDepartments(userId, new UserDepartmentRequest(departmentIds), actor, metadata);
    }

    private void validateDepartmentAssignment(List<String> ids) {
        if (ids == null || ids.size() > 20 || Set.copyOf(ids).size() != ids.size())
            throw new ApiException(HttpStatus.BAD_REQUEST, "部门编号列表不合法", "api.common.badRequest");
        if (repository.countDepartments(Set.copyOf(ids)) != ids.size())
            throw new ApiException(HttpStatus.BAD_REQUEST, "存在不存在的部门", "api.common.badRequest");
    }

    private void lockUser(String userId) {
        if (!repository.lockUser(userId)) throw new ApiException(HttpStatus.NOT_FOUND, "用户不存在", "api.common.notFound");
    }

    private DepartmentView requireDepartment(String id) {
        return repository
                .findDepartment(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "部门不存在", "api.common.notFound"));
    }

    private void requireUser(String userId) {
        if (!repository.userExists(userId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "用户不存在", "api.common.notFound");
        }
    }

    private void requireNoCycle(String id, String parentId) {
        String cursor = parentId;
        for (int depth = 0; StringUtils.hasText(cursor); depth++) {
            if (depth >= 100) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "部门层级过深或数据存在循环", "api.common.badRequest");
            }
            if (id.equals(cursor)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "上级部门不能形成循环", "api.common.badRequest");
            }
            cursor = repository
                    .findDepartment(cursor)
                    .map(DepartmentView::parentId)
                    .orElse(null);
        }
    }

    private static DepartmentView tree(DepartmentView parent, List<DepartmentView> rows) {
        List<DepartmentView> children = rows.stream()
                .filter(row -> parent.id().equals(row.parentId()))
                .map(row -> tree(row, rows))
                .toList();
        return new DepartmentView(
                parent.id(),
                parent.parentId(),
                parent.name(),
                parent.code(),
                parent.sortNo(),
                parent.status(),
                parent.createdAt(),
                parent.updatedAt(),
                children);
    }

    private static String nextId() {
        return String.valueOf(IDS.incrementAndGet());
    }
}
