package com.kaiwu.module.org.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.org.entity.DepartmentEntity;
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
}
