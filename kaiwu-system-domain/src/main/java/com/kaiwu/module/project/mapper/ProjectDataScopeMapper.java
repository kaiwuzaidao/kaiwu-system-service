package com.kaiwu.module.project.mapper;

import com.kaiwu.module.project.entity.DataScopeConfigRow;
import com.kaiwu.module.project.entity.DataScopeDepartmentCodeRow;
import com.kaiwu.module.project.entity.DataScopeDepartmentRow;
import com.kaiwu.module.project.entity.DataScopeResourceRow;
import com.kaiwu.module.project.entity.DataScopeRoleScopeRow;
import com.kaiwu.module.project.entity.DataScopeScopeDeptRow;
import com.kaiwu.module.project.entity.DataScopeUserDepartmentRow;
import java.util.Collection;
import java.util.List;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/**
 * 项目数据范围的数据访问（ADR 0044）。
 *
 * <p>SQL 只用 MySQL 与达梦共有的语法；部门树在内存里展开，不依赖递归查询。</p>
 */
@Mapper
public interface ProjectDataScopeMapper {

    /** 项目已启用的受控资源。 */
    @Select(
            """
            SELECT id, resource_code, resource_name, allowed_scopes, status
            FROM sys_project_data_resource
            WHERE project_id = #{projectId} AND status = 'ENABLED'
            ORDER BY resource_code
            """)
    List<DataScopeResourceRow> findEnabledResources(@Param("projectId") String projectId);

    /**
     * 成员全部有效角色及其数据范围配置；没有配置的角色也返回一行。
     *
     * <p>两张表的主键都叫 {@code id}，必须显式起别名：同名列会让构造器映射把配置行 ID 错取成角色 ID。</p>
     */
    @Select(
            """
            SELECT r.id AS role_id, r.role_code, r.built_in, s.id AS scope_id,
                   s.resource_code, s.scope_type, s.include_child
            FROM sys_project_member m
            JOIN sys_project_member_role mr
              ON mr.project_id = m.project_id AND mr.user_id = m.user_id
            JOIN sys_project_role r ON r.id = mr.role_id AND r.status = 'ACTIVE'
            LEFT JOIN sys_project_role_data_scope s ON s.role_id = r.id
            WHERE m.project_id = #{projectId} AND m.user_id = #{userId}
              AND m.status = 'ACTIVE'
            ORDER BY r.role_code, s.resource_code
            """)
    List<DataScopeRoleScopeRow> findMemberRoleScopes(
            @Param("projectId") String projectId, @Param("userId") String userId);

    /** 一批配置行勾选的部门。 */
    @Select(
            """
            <script>
            SELECT scope_id, department_id
            FROM sys_project_role_data_scope_dept
            WHERE scope_id IN
            <foreach collection="scopeIds" item="id" open="(" separator="," close=")">#{id}</foreach>
            ORDER BY scope_id, department_id
            </script>
            """)
    List<DataScopeScopeDeptRow> findScopeDepts(@Param("scopeIds") Collection<String> scopeIds);

    /** 全部部门的上下级关系。部门是组织档案，规模很小，且仅在需要展开下级时读取。 */
    @Select("SELECT id, parent_id FROM sys_department")
    List<DataScopeDepartmentRow> findDepartmentEdges();

    /** 用户所属的全部部门。 */
    @Select(
            """
            SELECT department_id, primary_department
            FROM sys_user_department
            WHERE user_id = #{userId}
            ORDER BY department_id
            """)
    List<DataScopeUserDepartmentRow> findUserDepartments(@Param("userId") String userId);

    /** 给定 ID 中确实存在的部门，用于校验勾选。 */
    @Select(
            """
            <script>
            SELECT id FROM sys_department
            WHERE id IN
            <foreach collection="ids" item="id" open="(" separator="," close=")">#{id}</foreach>
            </script>
            """)
    List<String> findExistingDepartmentIds(@Param("ids") Collection<String> ids);

    /** 某角色全部范围配置。 */
    @Select(
            """
            SELECT id, resource_code, scope_type, include_child
            FROM sys_project_role_data_scope
            WHERE role_id = #{roleId}
            ORDER BY resource_code
            """)
    List<DataScopeConfigRow> findRoleConfigs(@Param("roleId") String roleId);

    /** 删除某角色的全部范围配置；勾选的部门随外键级联删除。 */
    @Delete("DELETE FROM sys_project_role_data_scope WHERE role_id = #{roleId}")
    int deleteRoleConfigs(@Param("roleId") String roleId);

    /** 新增一条范围配置。 */
    @Insert(
            """
            INSERT INTO sys_project_role_data_scope
                (id, project_id, role_id, resource_code, scope_type, include_child, created_at, updated_at)
            VALUES (#{id}, #{projectId}, #{roleId}, #{resourceCode}, #{scopeType}, #{includeChild},
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int insertRoleConfig(
            @Param("id") String id,
            @Param("projectId") String projectId,
            @Param("roleId") String roleId,
            @Param("resourceCode") String resourceCode,
            @Param("scopeType") String scopeType,
            @Param("includeChild") boolean includeChild);

    /** 新增一条勾选的部门。 */
    @Insert(
            """
            INSERT INTO sys_project_role_data_scope_dept (scope_id, department_id)
            VALUES (#{scopeId}, #{departmentId})
            """)
    int insertScopeDept(@Param("scopeId") String scopeId, @Param("departmentId") String departmentId);

    /** 项目登记的全部受控资源，含已下线的。 */
    @Select(
            """
            SELECT id, resource_code, resource_name, allowed_scopes, status
            FROM sys_project_data_resource
            WHERE project_id = #{projectId}
            ORDER BY resource_code
            """)
    List<DataScopeResourceRow> findAllResources(@Param("projectId") String projectId);

    /** 新增受控资源，初始启用。 */
    @Insert(
            """
            INSERT INTO sys_project_data_resource
                (id, project_id, resource_code, resource_name, allowed_scopes, status, created_at, updated_at)
            VALUES (#{id}, #{projectId}, #{resourceCode}, #{resourceName}, #{allowedScopes}, 'ENABLED',
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int insertResource(
            @Param("id") String id,
            @Param("projectId") String projectId,
            @Param("resourceCode") String resourceCode,
            @Param("resourceName") String resourceName,
            @Param("allowedScopes") String allowedScopes);

    /** 更新展示名与允许范围，并重新启用。 */
    @Update(
            """
            UPDATE sys_project_data_resource
            SET resource_name = #{resourceName}, allowed_scopes = #{allowedScopes}, status = 'ENABLED',
                updated_at = CURRENT_TIMESTAMP
            WHERE id = #{id}
            """)
    int updateResource(
            @Param("id") String id,
            @Param("resourceName") String resourceName,
            @Param("allowedScopes") String allowedScopes);

    /** 资源上范围类型不在给定集合内的配置数，用于告知管理员收窄允许范围的影响。 */
    @Select(
            """
            <script>
            SELECT COUNT(*) FROM sys_project_role_data_scope
            WHERE project_id = #{projectId} AND resource_code = #{resourceCode}
              AND scope_type NOT IN
            <foreach collection="allowed" item="type" open="(" separator="," close=")">#{type}</foreach>
            </script>
            """)
    long countConfigsOutside(
            @Param("projectId") String projectId,
            @Param("resourceCode") String resourceCode,
            @Param("allowed") Collection<String> allowed);

    /** 按部门编码查部门，只返回存在的。 */
    @Select(
            """
            <script>
            SELECT id, dept_code FROM sys_department
            WHERE dept_code IN
            <foreach collection="codes" item="code" open="(" separator="," close=")">#{code}</foreach>
            </script>
            """)
    List<DataScopeDepartmentCodeRow> findDepartmentsByCodes(@Param("codes") Collection<String> codes);

    /** 按部门 ID 查编码，只返回存在的。 */
    @Select(
            """
            <script>
            SELECT id, dept_code FROM sys_department
            WHERE id IN
            <foreach collection="ids" item="id" open="(" separator="," close=")">#{id}</foreach>
            </script>
            """)
    List<DataScopeDepartmentCodeRow> findDepartmentsByIds(@Param("ids") Collection<String> ids);
}
