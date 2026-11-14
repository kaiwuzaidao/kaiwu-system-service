package com.kaiwu.module.project.repository;

import com.kaiwu.module.project.entity.DataScopeConfigRow;
import com.kaiwu.module.project.entity.DataScopeDepartmentCodeRow;
import com.kaiwu.module.project.entity.DataScopeDepartmentRow;
import com.kaiwu.module.project.entity.DataScopeResourceRow;
import com.kaiwu.module.project.entity.DataScopeRoleScopeRow;
import com.kaiwu.module.project.entity.DataScopeScopeDeptRow;
import com.kaiwu.module.project.entity.DataScopeUserDepartmentRow;
import com.kaiwu.module.project.mapper.ProjectDataScopeMapper;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Repository;

/**
 * 项目数据范围的数据访问组合：把 Mapper 的行投影整理成服务需要的集合形态，并处理空集合不下发 SQL。
 */
@Repository
public class ProjectDataScopeRepository {

    private final ProjectDataScopeMapper mapper;

    /** 注入 Mapper。 */
    public ProjectDataScopeRepository(ProjectDataScopeMapper mapper) {
        this.mapper = mapper;
    }

    /** 项目已启用的受控资源，按资源码排序。 */
    public List<DataScopeResourceRow> findEnabledResources(String projectId) {
        return mapper.findEnabledResources(projectId);
    }

    /** 项目登记的全部受控资源，含已下线的。 */
    public List<DataScopeResourceRow> findAllResources(String projectId) {
        return mapper.findAllResources(projectId);
    }

    /** 新增或更新受控资源（按资源码），更新时一并重新启用。 */
    public void saveResource(String projectId, String code, String name, String allowedScopes, IdSupplier ids) {
        DataScopeResourceRow current = mapper.findAllResources(projectId).stream()
                .filter(row -> row.resourceCode().equals(code))
                .findFirst()
                .orElse(null);
        if (current == null) {
            mapper.insertResource(ids.next(), projectId, code, name, allowedScopes);
        } else {
            mapper.updateResource(current.id(), name, allowedScopes);
        }
    }

    /** 资源上范围类型不在给定集合内的配置数。 */
    public long countConfigsOutside(String projectId, String code, Collection<String> allowed) {
        return mapper.countConfigsOutside(projectId, code, allowed);
    }

    /** 成员全部有效角色及其配置行。 */
    public List<DataScopeRoleScopeRow> findMemberRoleScopes(String projectId, String userId) {
        return mapper.findMemberRoleScopes(projectId, userId);
    }

    /** 配置行 ID 到其勾选部门集合；没有勾选的配置不出现在结果里。 */
    public Map<String, Set<String>> findScopeDepts(Collection<String> scopeIds) {
        if (scopeIds.isEmpty()) {
            return Map.of();
        }
        Map<String, Set<String>> result = new HashMap<>();
        for (DataScopeScopeDeptRow row : mapper.findScopeDepts(scopeIds)) {
            result.computeIfAbsent(row.scopeId(), key -> new HashSet<>()).add(row.departmentId());
        }
        return result;
    }

    /** 部门 ID 到直接下级 ID 列表。 */
    public Map<String, List<String>> findChildrenByParent() {
        Map<String, List<String>> children = new HashMap<>();
        for (DataScopeDepartmentRow edge : mapper.findDepartmentEdges()) {
            if (edge.parentId() != null) {
                children.computeIfAbsent(edge.parentId(), key -> new ArrayList<>())
                        .add(edge.id());
            }
        }
        return children;
    }

    /** 用户所属部门，主部门单独标记。 */
    public List<DataScopeUserDepartmentRow> findUserDepartments(String userId) {
        return mapper.findUserDepartments(userId);
    }

    /** 部门编码到部门 ID，只含目标环境里存在的编码。 */
    public Map<String, String> departmentIdsByCode(Collection<String> codes) {
        Map<String, String> result = new HashMap<>();
        if (!codes.isEmpty()) {
            for (DataScopeDepartmentCodeRow row : mapper.findDepartmentsByCodes(codes)) {
                result.put(row.deptCode(), row.id());
            }
        }
        return result;
    }

    /** 部门 ID 到部门编码，只含存在的部门。 */
    public Map<String, String> departmentCodesById(Collection<String> ids) {
        Map<String, String> result = new HashMap<>();
        if (!ids.isEmpty()) {
            for (DataScopeDepartmentCodeRow row : mapper.findDepartmentsByIds(ids)) {
                result.put(row.id(), row.deptCode());
            }
        }
        return result;
    }

    /** 给定部门 ID 中真实存在的那部分。 */
    public Set<String> findExistingDepartmentIds(Collection<String> ids) {
        if (ids.isEmpty()) {
            return Set.of();
        }
        return new HashSet<>(mapper.findExistingDepartmentIds(ids));
    }

    /** 某角色全部配置及其勾选部门，按资源码索引。 */
    public Map<String, StoredConfig> findRoleConfigs(String roleId) {
        List<DataScopeConfigRow> rows = mapper.findRoleConfigs(roleId);
        Map<String, Set<String>> depts =
                findScopeDepts(rows.stream().map(DataScopeConfigRow::id).toList());
        Map<String, StoredConfig> result = new LinkedHashMap<>();
        for (DataScopeConfigRow row : rows) {
            result.put(
                    row.resourceCode(),
                    new StoredConfig(
                            row.id(), row.scopeType(), row.includeChild(), depts.getOrDefault(row.id(), Set.of())));
        }
        return result;
    }

    /** 整体替换某角色的配置：先清空再写入，调用方负责事务和角色行锁。 */
    public void replaceRoleConfigs(String projectId, String roleId, List<NewConfig> configs, IdSupplier ids) {
        mapper.deleteRoleConfigs(roleId);
        for (NewConfig config : configs) {
            String id = ids.next();
            mapper.insertRoleConfig(
                    id, projectId, roleId, config.resourceCode(), config.scopeType(), config.includeChild());
            for (String departmentId : config.deptIds()) {
                mapper.insertScopeDept(id, departmentId);
            }
        }
    }

    /**
     * 已存储的一条配置。
     *
     * @param id           行 ID
     * @param scopeType    范围类型原始字符串
     * @param includeChild 是否含下级
     * @param deptIds      勾选的部门
     */
    public record StoredConfig(String id, String scopeType, boolean includeChild, Set<String> deptIds) {}

    /**
     * 待写入的一条配置。
     *
     * @param resourceCode 资源码
     * @param scopeType    范围类型
     * @param includeChild 是否含下级
     * @param deptIds      勾选的部门，非 {@code CUSTOM_DEPT} 时为空
     */
    public record NewConfig(String resourceCode, String scopeType, boolean includeChild, List<String> deptIds) {}

    /** 行 ID 生成器，便于测试注入确定值。 */
    @FunctionalInterface
    public interface IdSupplier {

        /** 下一个行 ID。 */
        String next();
    }
}
