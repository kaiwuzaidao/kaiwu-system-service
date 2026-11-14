package com.kaiwu.module.factory.mapper;

import com.kaiwu.module.factory.entity.ProjectHandoverRow;
import java.util.List;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

/** 项目配置移交记录 Mapper（ADR 0042）。查询显式列出字段，顺序与 {@link ProjectHandoverRow} 一致。 */
@Mapper
public interface ProjectHandoverMapper {

    /** 摘要列：不含两个大文本列。 */
    String COLUMNS =
            """
            id, project_id, status, package_digest, source_host, source_exported_by, source_exported_at,
            plan_hash, git_commit, applied_access, change_count, delete_count, failure_reason, operator_id,
            created_at
            """;

    /**
     * 写入一条移交记录。
     *
     * @param row 记录摘要，创建时间由数据库生成
     * @param changesJson 本次计划的全部条目
     * @param keysJson 移交包内全部条目的业务键，失败记录传 {@code null}
     * @return 写入行数
     */
    @Insert(
            """
            INSERT INTO sys_project_config_handover
                (id, project_id, status, package_digest, source_host, source_exported_by, source_exported_at,
                 plan_hash, git_commit, applied_access, change_count, delete_count, failure_reason,
                 changes_json, keys_json, operator_id, created_at)
            VALUES (#{row.id}, #{row.projectId}, #{row.status}, #{row.packageDigest}, #{row.sourceHost},
                    #{row.sourceExportedBy}, #{row.sourceExportedAt}, #{row.planHash}, #{row.gitCommit},
                    #{row.appliedAccess}, #{row.changeCount}, #{row.deleteCount}, #{row.failureReason},
                    #{changesJson}, #{keysJson}, #{row.operatorId}, CURRENT_TIMESTAMP)
            """)
    int insert(
            @Param("row") ProjectHandoverRow row,
            @Param("changesJson") String changesJson,
            @Param("keysJson") String keysJson);

    /**
     * 项目的移交记录，最新在前。
     *
     * @param projectId 项目 ID
     * @param limit 最多返回条数
     * @return 记录摘要
     */
    @Select("SELECT " + COLUMNS + " FROM sys_project_config_handover WHERE project_id = #{projectId} "
            + "ORDER BY created_at DESC, id DESC LIMIT #{limit}")
    List<ProjectHandoverRow> list(@Param("projectId") String projectId, @Param("limit") int limit);

    /**
     * 按 ID 查询记录摘要，限定项目，防止跨项目读取。
     *
     * @param projectId 项目 ID
     * @param id 记录 ID
     * @return 记录，不存在时为 {@code null}
     */
    @Select("SELECT " + COLUMNS + " FROM sys_project_config_handover WHERE project_id = #{projectId} AND id = #{id}")
    ProjectHandoverRow find(@Param("projectId") String projectId, @Param("id") String id);

    /**
     * 记录的计划条目 JSON。
     *
     * @param projectId 项目 ID
     * @param id 记录 ID
     * @return 条目 JSON，无记录或为空时为 {@code null}
     */
    @Select("SELECT changes_json FROM sys_project_config_handover WHERE project_id = #{projectId} AND id = #{id}")
    String changesJson(@Param("projectId") String projectId, @Param("id") String id);

    /**
     * 最近一次成功移交的业务键 JSON，即删除比对的基线。
     *
     * @param projectId 项目 ID
     * @return 业务键 JSON，没有成功记录时为 {@code null}
     */
    @Select("SELECT keys_json FROM sys_project_config_handover WHERE project_id = #{projectId} "
            + "AND status = 'SUCCESS' AND keys_json IS NOT NULL ORDER BY created_at DESC, id DESC LIMIT 1")
    String latestSuccessKeysJson(@Param("projectId") String projectId);

    /**
     * 同一摘要最近一次成功移交，用于提示「这个包已经导入过」。
     *
     * @param projectId 项目 ID
     * @param digest 移交包摘要
     * @return 记录，没有时为 {@code null}
     */
    @Select("SELECT " + COLUMNS + " FROM sys_project_config_handover WHERE project_id = #{projectId} "
            + "AND status = 'SUCCESS' AND package_digest = #{digest} ORDER BY created_at DESC, id DESC LIMIT 1")
    ProjectHandoverRow latestSuccessByDigest(@Param("projectId") String projectId, @Param("digest") String digest);
}
