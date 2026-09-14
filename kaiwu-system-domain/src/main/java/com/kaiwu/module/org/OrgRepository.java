package com.kaiwu.module.org;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.kaiwu.module.org.entity.DepartmentEntity;
import com.kaiwu.module.org.entity.UserDepartmentEntity;
import com.kaiwu.module.org.mapper.DepartmentMapper;
import com.kaiwu.module.org.mapper.UserDepartmentMapper;
import com.kaiwu.module.org.vo.DepartmentView;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.stereotype.Repository;
import org.springframework.util.StringUtils;

/** 组织架构数据访问。 */
@Repository
public class OrgRepository {

    private final DepartmentMapper departmentMapper;
    private final UserDepartmentMapper userDepartmentMapper;

    public OrgRepository(DepartmentMapper departmentMapper, UserDepartmentMapper userDepartmentMapper) {
        this.departmentMapper = departmentMapper;
        this.userDepartmentMapper = userDepartmentMapper;
    }

    /** 全部部门的扁平列表，按 sort_no 排序；组装成树由 Service 负责。 */
    public List<DepartmentView> departments() {
        return departmentMapper
                .selectList(new LambdaQueryWrapper<DepartmentEntity>()
                        .orderByAsc(DepartmentEntity::getSortNo)
                        .orderByAsc(DepartmentEntity::getDeptName)
                        .orderByAsc(DepartmentEntity::getId))
                .stream()
                .map(OrgRepository::toView)
                .toList();
    }

    public Optional<DepartmentView> findDepartment(String id) {
        return Optional.ofNullable(departmentMapper.selectById(Long.parseLong(id)))
                .map(OrgRepository::toView);
    }

    /**
     * 部门编码是否已被占用。
     *
     * @param excludedId 编辑时传自身 ID 以排除，否则「改名不改编码」会被误判为重复
     */
    public boolean codeExists(String code, String excludedId) {
        LambdaQueryWrapper<DepartmentEntity> query =
                new LambdaQueryWrapper<DepartmentEntity>().eq(DepartmentEntity::getDeptCode, code);
        // 编辑时要把自己排除掉，否则「改名不改编码」会被误判为编码重复。
        if (StringUtils.hasText(excludedId)) {
            query.ne(DepartmentEntity::getId, Long.parseLong(excludedId));
        }
        return departmentMapper.exists(query);
    }

    /** 新增或编辑部门；同一方法承担两种场景，由数据库的主键冲突判定走哪条分支。 */
    public void saveDepartment(String id, String parentId, String name, String code, int sortNo, String status) {
        departmentMapper.upsert(
                Long.parseLong(id),
                StringUtils.hasText(parentId) ? Long.parseLong(parentId) : null,
                name,
                code,
                sortNo,
                status);
    }

    public int childCount(String id) {
        return Math.toIntExact(departmentMapper.selectCount(
                new LambdaQueryWrapper<DepartmentEntity>().eq(DepartmentEntity::getParentId, Long.parseLong(id))));
    }

    public int assignmentCount(String id) {
        return userDepartmentMapper.countByDepartment(Long.parseLong(id));
    }

    public void deleteDepartment(String id) {
        departmentMapper.deleteById(Long.parseLong(id));
    }

    public boolean userExists(String userId) {
        return departmentMapper.countUser(Long.parseLong(userId)) == 1;
    }

    /** 给定部门 ID 中实际存在的条数，用于分配前校验是否有不存在的部门。 */
    public int countDepartments(Set<String> ids) {
        if (ids.isEmpty()) return 0;
        return Math.toIntExact(departmentMapper.selectCount(new LambdaQueryWrapper<DepartmentEntity>()
                .in(DepartmentEntity::getId, ids.stream().map(Long::parseLong).toList())));
    }

    public List<String> userDepartmentIds(String userId) {
        return userDepartmentMapper.findDepartmentIds(Long.parseLong(userId));
    }

    /** 列表页一次性带出多个用户的部门，避免 N+1；主部门排在每个用户的最前。 */
    public Map<String, List<String>> userDepartmentIdsByUsers(List<String> userIds) {
        if (userIds.isEmpty()) return Map.of();
        Map<String, List<String>> result = new LinkedHashMap<>();
        userDepartmentMapper
                .selectList(new LambdaQueryWrapper<UserDepartmentEntity>()
                        .in(
                                UserDepartmentEntity::getUserId,
                                userIds.stream().map(Long::parseLong).toList())
                        .orderByAsc(UserDepartmentEntity::getUserId)
                        .orderByDesc(UserDepartmentEntity::getPrimaryDepartment)
                        .orderByAsc(UserDepartmentEntity::getCreatedAt)
                        .orderByAsc(UserDepartmentEntity::getDepartmentId))
                .forEach(row -> result.computeIfAbsent(String.valueOf(row.getUserId()), k -> new ArrayList<>())
                        .add(String.valueOf(row.getDepartmentId())));
        return result;
    }

    /**
     * 按给定编码顺序返回部门 ID。
     *
     * <p>顺序有业务含义：导入场景把第一个部门当作主部门。迁移前靠 MySQL 专有的
     * {@code ORDER BY FIELD(...)} 实现，需要把编码列表拼进 SQL 两次；现在改成一次
     * {@code in()} 查询 + Java 侧按入参顺序重排，既去掉了动态 SQL，也不再依赖方言。</p>
     */
    public List<String> findDepartmentIdsByCodes(List<String> codes) {
        if (codes.isEmpty()) return List.of();
        Map<String, String> idByCode = departmentMapper
                .selectList(new LambdaQueryWrapper<DepartmentEntity>().in(DepartmentEntity::getDeptCode, codes))
                .stream()
                .collect(Collectors.toMap(DepartmentEntity::getDeptCode, entity -> String.valueOf(entity.getId())));
        return codes.stream().map(idByCode::get).filter(Objects::nonNull).toList();
    }

    /** 全量覆盖用户的部门归属（先清空再写入）；列表第一个写为主部门。 */
    public void replaceUserDepartments(String userId, List<String> departmentIds) {
        long user = Long.parseLong(userId);
        userDepartmentMapper.deleteByUser(user);
        for (int index = 0; index < departmentIds.size(); index++) {
            // 列表第一个即主部门，与 userDepartmentIds 的排序约定保持一致。
            userDepartmentMapper.insert(user, Long.parseLong(departmentIds.get(index)), index == 0);
        }
    }

    private static DepartmentView toView(DepartmentEntity entity) {
        return new DepartmentView(
                String.valueOf(entity.getId()),
                entity.getParentId() == null ? null : String.valueOf(entity.getParentId()),
                entity.getDeptName(),
                entity.getDeptCode(),
                entity.getSortNo() == null ? 0 : entity.getSortNo(),
                entity.getStatus(),
                entity.getCreatedAt(),
                entity.getUpdatedAt(),
                List.of());
    }
}
