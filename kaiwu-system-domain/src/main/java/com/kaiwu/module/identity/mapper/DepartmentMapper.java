package com.kaiwu.module.identity.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.identity.entity.DepartmentEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/** 部门 Mapper。 */
@Mapper
public interface DepartmentMapper extends BaseMapper<DepartmentEntity> {

    /**
     * 新增或更新部门。
     *
     * <p>调用方在新增和编辑两种场景下都走这一个方法，且编辑时不重新生成 ID，
     * 因此保留 upsert 语义；拆成 insert/update 两条会把「是新增还是编辑」的判断
     * 推回到 Service，而那个判断在数据库这一侧才是权威的。</p>
     */
    @Update(
            databaseId = "dm",
            value =
                    """
            MERGE INTO sys_department t
            USING (
            SELECT incoming.id, incoming.parent_id, incoming.dept_name, incoming.dept_code, incoming.sort_no, incoming.status, incoming.created_at, incoming.updated_at, (SELECT existing.id FROM sys_department existing WHERE (existing.id = incoming.id) OR (existing.dept_code = incoming.dept_code)) AS match_id
            FROM (
            SELECT #{id} AS id,
                   #{parentId} AS parent_id,
                   #{name} AS dept_name,
                   #{code} AS dept_code,
                   #{sortNo} AS sort_no,
                   #{status} AS status,
                   CURRENT_TIMESTAMP AS created_at,
                   CURRENT_TIMESTAMP AS updated_at
            FROM dual
            ) incoming
            ) s
            ON (t.id = s.match_id)
            WHEN MATCHED THEN UPDATE SET t.parent_id = s.parent_id,
                t.dept_name = s.dept_name,
                t.dept_code = s.dept_code,
                t.sort_no = s.sort_no,
                t.status = s.status,
                t.updated_at = CURRENT_TIMESTAMP
            WHEN NOT MATCHED THEN INSERT (id, parent_id, dept_name, dept_code, sort_no, status, created_at, updated_at)
            VALUES (s.id, s.parent_id, s.dept_name, s.dept_code, s.sort_no, s.status, s.created_at, s.updated_at)
            """)
    @Update(
            """
            INSERT INTO sys_department
                (id, parent_id, dept_name, dept_code, sort_no, status, created_at, updated_at)
            VALUES (#{id}, #{parentId}, #{name}, #{code}, #{sortNo}, #{status},
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON DUPLICATE KEY UPDATE
                parent_id = VALUES(parent_id), dept_name = VALUES(dept_name),
                dept_code = VALUES(dept_code), sort_no = VALUES(sort_no),
                status = VALUES(status), updated_at = CURRENT_TIMESTAMP
            """)
    int upsert(
            @Param("id") long id,
            @Param("parentId") Long parentId,
            @Param("name") String name,
            @Param("code") String code,
            @Param("sortNo") int sortNo,
            @Param("status") String status);

    /** 用户是否存在；用户表归 user 模块所有，这里只做存在性校验。 */
    @Select("SELECT COUNT(*) FROM sys_user WHERE id = #{userId}")
    int countUser(@Param("userId") long userId);

    /** Serialize user-department replacements, including the first assignment. */
    @Select("SELECT id FROM sys_user WHERE id = #{userId} FOR UPDATE")
    Long lockUser(@Param("userId") long userId);
}
