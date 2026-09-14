package com.kaiwu.module.search.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

/**
 * 全局搜索 Mapper。
 *
 * <p>**有意不继承 {@code BaseMapper}**：这里全是跨表只读查询，没有对应的单表实体。
 * 硬造一个「搜索实体」只会多出一个没有表与之对应的类。</p>
 *
 * <p>可见性条件用 {@code <if>} 表达：非管理员只能搜到自己是有效成员的项目。
 * 迁移前这段是字符串拼接 + 两套参数数组，参数个数随分支变化，加条件时极易错位。</p>
 */
@Mapper
public interface GlobalSearchMapper {

    /**
     * 可见性条件用 {@code EXISTS} 而不是条件 JOIN。
     *
     * <p>迁移前是「非管理员才拼上一个 JOIN」，需要 {@code <if>} 改变 SQL 结构；
     * 换成 {@code #{listAll} = TRUE OR EXISTS (...)} 后整条 SQL 是静态的。
     * EXISTS 语义上还更稳：条件 JOIN 在同一用户有多行成员记录时会产生重复项目行，
     * EXISTS 不会。</p>
     */
    @Select(
            """
            SELECT project.id AS id, project.project_name AS projectName,
                   project.project_code AS projectCode
            FROM sys_project project
            WHERE project.status <> 'ARCHIVED'
              AND (project.project_name LIKE #{keyword} OR project.project_code LIKE #{keyword})
              AND (#{listAll} = TRUE OR EXISTS (
                    SELECT 1 FROM sys_project_member member
                    WHERE member.project_id = project.id
                      AND member.user_id = #{userId}
                      AND member.status = 'ACTIVE'
              ))
            ORDER BY project.updated_at DESC
            LIMIT 6
            """)
    List<Map<String, Object>> searchProjects(
            @Param("keyword") String keyword, @Param("userId") String userId, @Param("listAll") boolean listAll);

    @Select(
            """
            SELECT id AS id, username AS username, display_name AS displayName,
                   status AS status
            FROM sys_user
            WHERE username LIKE #{keyword} OR display_name LIKE #{keyword}
               OR email LIKE #{keyword}
            ORDER BY updated_at DESC
            LIMIT 6
            """)
    List<Map<String, Object>> searchUsers(@Param("keyword") String keyword);

    @Select(
            """
            SELECT generation.task_no AS taskNo, project.project_name AS projectName,
                   project.project_code AS projectCode,
                   generation.generation_status AS generationStatus
            FROM sys_project_generation generation
            JOIN sys_project project ON project.id = generation.project_id
            WHERE (project.project_name LIKE #{keyword} OR project.project_code LIKE #{keyword}
                   OR generation.task_no LIKE #{keyword})
              AND (#{listAll} = TRUE
                   OR generation.owner_user_id = #{userId}
                   OR EXISTS (
                        SELECT 1 FROM sys_project_member member
                        WHERE member.project_id = project.id
                          AND member.user_id = #{userId}
                          AND member.status = 'ACTIVE'
                   ))
            ORDER BY generation.updated_at DESC
            LIMIT 6
            """)
    List<Map<String, Object>> searchDeliveries(
            @Param("keyword") String keyword, @Param("userId") String userId, @Param("listAll") boolean listAll);
}
