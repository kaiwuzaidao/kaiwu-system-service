package com.kaiwu.module.org.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.org.entity.UserDepartmentEntity;
import java.util.List;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

/**
 * 用户与部门的关联表 Mapper。
 *
 * <p>实体 {@link UserDepartmentEntity} 有意不标 {@code @TableId}：复合主键标在任何单列上
 * 都是假话。这样 {@code selectById} / {@code updateById} 用不了（本来也不该用），而
 * {@code selectList(wrapper)} 可用，批量查询因此不需要动态 SQL。写入仍走注解 SQL：
 * {@code created_at} 由数据库时间填充，比构造实体更直白。</p>
 */
@Mapper
public interface UserDepartmentMapper extends BaseMapper<UserDepartmentEntity> {

    /** 该用户的部门 ID，主部门排在最前。 */
    @Select(
            """
            SELECT department_id FROM sys_user_department
            WHERE user_id = #{userId}
            ORDER BY primary_department DESC, created_at, department_id
            """)
    List<String> findDepartmentIds(@Param("userId") long userId);

    /** 关联到该部门的用户数，用于删除部门前的占用校验。 */
    @Select("SELECT COUNT(*) FROM sys_user_department WHERE department_id = #{departmentId}")
    int countByDepartment(@Param("departmentId") long departmentId);

    @Delete("DELETE FROM sys_user_department WHERE user_id = #{userId}")
    int deleteByUser(@Param("userId") long userId);

    /** 写入一条关联；{@code primary} 为 true 表示主部门。 */
    @Insert(
            """
            INSERT INTO sys_user_department
                (user_id, department_id, primary_department, created_at)
            VALUES (#{userId}, #{departmentId}, #{primary}, CURRENT_TIMESTAMP)
            """)
    int insert(
            @Param("userId") long userId, @Param("departmentId") long departmentId, @Param("primary") boolean primary);
}
