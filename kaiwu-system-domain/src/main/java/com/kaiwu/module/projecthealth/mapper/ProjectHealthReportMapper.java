package com.kaiwu.module.projecthealth.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.projecthealth.entity.ProjectHealthReportEntity;
import java.time.LocalDateTime;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/**
 * 项目体检报告 Mapper。
 *
 * <p>体检开关存在 {@code sys_project} 上，属于 project 模块的表。这里只用注解 SQL 读写
 * 那一列，不引入第二份 {@code sys_project} 实体——同一张表两份实体是迁移过程中最容易
 * 埋下的漂移源。</p>
 */
@Mapper
public interface ProjectHealthReportMapper extends BaseMapper<ProjectHealthReportEntity> {

    /** 该项目是否开启只读体检；项目不存在时返回 null，由调用方按「未开启」处理。 */
    @Select("SELECT health_check_enabled FROM sys_project WHERE id = #{projectId}")
    Boolean healthCheckEnabled(@Param("projectId") long projectId);

    @Update(
            """
            UPDATE sys_project
            SET health_check_enabled = #{enabled}, updated_at = #{updatedAt}
            WHERE id = #{projectId}
            """)
    int setHealthCheckEnabled(
            @Param("projectId") long projectId,
            @Param("enabled") boolean enabled,
            @Param("updatedAt") LocalDateTime updatedAt);

    /**
     * 写入本次体检结论。
     *
     * <p>每个项目一行，重复体检覆盖同一行，因此用 {@code ON DUPLICATE KEY UPDATE}
     * 而不是先删后插——后者在并发体检时会出现短暂的「报告不存在」。</p>
     */
    @Update(
            """
            INSERT INTO sys_project_health_report
                (project_id, verdict, checks_json, checked_at, created_at, updated_at)
            VALUES (#{projectId}, #{verdict}, #{checksJson}, #{checkedAt},
                    #{checkedAt}, #{checkedAt})
            ON DUPLICATE KEY UPDATE
                verdict = VALUES(verdict),
                checks_json = VALUES(checks_json),
                checked_at = VALUES(checked_at),
                updated_at = VALUES(updated_at)
            """)
    int upsert(
            @Param("projectId") long projectId,
            @Param("verdict") String verdict,
            @Param("checksJson") String checksJson,
            @Param("checkedAt") LocalDateTime checkedAt);
}
