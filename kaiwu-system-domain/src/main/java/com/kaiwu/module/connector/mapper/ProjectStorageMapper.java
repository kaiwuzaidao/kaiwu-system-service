package com.kaiwu.module.connector.mapper;

import com.kaiwu.module.connector.entity.ProjectStorageRow;
import java.util.List;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/** 项目存储绑定 Mapper（ADR 0039）。查询字段顺序与 {@link ProjectStorageRow} 一致。 */
@Mapper
public interface ProjectStorageMapper {

    /** 绑定查询的公共字段与关联。 */
    String SELECT =
            """
            SELECT s.id, s.project_id, p.project_code, p.project_name, s.storage_name, s.account_id,
                   a.account_name, a.bucket, s.status, s.max_object_bytes, s.allowed_content_types, s.created_at
            FROM sys_project_storage s
            JOIN sys_project p ON p.id = s.project_id
            JOIN sys_storage_account a ON a.id = s.account_id
            """;

    /**
     * 列出绑定，最多 500 条。
     *
     * @param projectId 只看某个项目时传入，为空表示全部项目
     * @return 按项目、存储名、创建时间倒序排列的绑定
     */
    @Select(
            """
            <script>
            """
                    + SELECT
                    + """
            <where><if test="projectId != null">s.project_id = #{projectId}</if></where>
            ORDER BY p.project_code, s.storage_name, s.created_at DESC, s.id DESC
            LIMIT 500
            </script>
            """)
    List<ProjectStorageRow> listBindings(@Param("projectId") String projectId);

    /**
     * 列出项目可签发凭证的绑定：生效与只读，最多 50 条。
     *
     * @param projectId 项目 ID，来自项目服务凭据
     * @return 绑定列表
     */
    @Select(
            SELECT
                    + """
            WHERE s.project_id = #{projectId} AND s.status IN ('ACTIVE', 'READ_ONLY')
            ORDER BY s.storage_name, s.created_at DESC
            LIMIT 50
            """)
    List<ProjectStorageRow> listIssuable(@Param("projectId") String projectId);

    /**
     * 按 ID 查询绑定。
     *
     * @param id 绑定 ID
     * @return 绑定，不存在时为 {@code null}
     */
    @Select(SELECT + " WHERE s.id = #{id}")
    ProjectStorageRow findBinding(@Param("id") String id);

    /**
     * 锁定并读取项目某个存储名当前生效的绑定，保证切换时不会出现两条生效绑定。
     *
     * @param projectId 项目 ID
     * @param storageName 存储名
     * @return 生效绑定，不存在时为 {@code null}
     */
    @Select(
            SELECT
                    + """
            WHERE s.project_id = #{projectId} AND s.storage_name = #{storageName} AND s.status = 'ACTIVE'
            FOR UPDATE
            """)
    ProjectStorageRow lockActive(@Param("projectId") String projectId, @Param("storageName") String storageName);

    /**
     * 查询项目编码。
     *
     * @param projectId 项目 ID
     * @return 项目编码，项目不存在时为 {@code null}
     */
    @Select("SELECT project_code FROM sys_project WHERE id = #{projectId}")
    String findProjectCode(@Param("projectId") String projectId);

    /**
     * 新建绑定。
     *
     * @param id 绑定 ID
     * @param projectId 项目 ID
     * @param storageName 存储名
     * @param accountId 账号 ID
     * @param status 初始状态
     * @param maxObjectBytes 单个对象字节上限
     * @param allowedContentTypes 逗号分隔的 MIME 类型，可空
     * @return 写入行数
     */
    @Insert(
            """
            INSERT INTO sys_project_storage
                (id, project_id, storage_name, account_id, status, max_object_bytes, allowed_content_types,
                 created_at, updated_at)
            VALUES (#{id}, #{projectId}, #{storageName}, #{accountId}, #{status}, #{maxObjectBytes},
                    #{allowedContentTypes}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int insertBinding(
            @Param("id") String id,
            @Param("projectId") String projectId,
            @Param("storageName") String storageName,
            @Param("accountId") String accountId,
            @Param("status") String status,
            @Param("maxObjectBytes") long maxObjectBytes,
            @Param("allowedContentTypes") String allowedContentTypes);

    /**
     * 修改绑定的上传限制。
     *
     * @param id 绑定 ID
     * @param maxObjectBytes 单个对象字节上限
     * @param allowedContentTypes 逗号分隔的 MIME 类型，可空
     * @return 更新行数
     */
    @Update(
            """
            UPDATE sys_project_storage
            SET max_object_bytes = #{maxObjectBytes}, allowed_content_types = #{allowedContentTypes},
                updated_at = CURRENT_TIMESTAMP
            WHERE id = #{id}
            """)
    int updateLimits(
            @Param("id") String id,
            @Param("maxObjectBytes") long maxObjectBytes,
            @Param("allowedContentTypes") String allowedContentTypes);

    /**
     * 修改绑定状态。
     *
     * @param id 绑定 ID
     * @param status 目标状态
     * @return 更新行数
     */
    @Update("UPDATE sys_project_storage SET status = #{status}, updated_at = CURRENT_TIMESTAMP WHERE id = #{id}")
    int updateStatus(@Param("id") String id, @Param("status") String status);
}
