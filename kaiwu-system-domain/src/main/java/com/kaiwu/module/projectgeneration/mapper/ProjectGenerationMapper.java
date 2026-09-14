package com.kaiwu.module.projectgeneration.mapper;

import com.kaiwu.module.projectgeneration.entity.ProjectGenerationJoinRow;
import com.kaiwu.module.projectgeneration.entity.ProjectRepositoryRow;
import java.util.List;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/**
 * 项目生成任务与远端仓库 Mapper。
 *
 * <p>这里当前是短小、静态的状态机 SQL，因此直接保留注解表达，也不继承 {@code BaseMapper}。
 * 本模块几乎每条 UPDATE 都带状态守卫（{@code AND generation_status = 'RUNNING'}、
 * {@code AND push_status IN ('NOT_CONFIGURED','FAILED')}），靠「更新影响行数是否为 1」
 * 实现无锁的状态机抢占。这些守卫是并发正确性本身：换成先查后改会出现两个线程同时
 * 认领同一个任务。用实体更新还会因为 MyBatis-Plus 跳过 null 而写不进
 * {@code last_error = NULL} 这类「清空」语义，重试后旧的错误信息会留在界面上。后续出现动态条件、
 * 多段联表或较长结果映射时，应迁入 Mapper XML，避免把复杂查询塞进 Java 注解。</p>
 *
 * <p>{@code sys_project_repository} 是复合主键 {@code (project_id, repository_type)}，
 * 同样不套 {@code BaseMapper}。</p>
 */
@Mapper
public interface ProjectGenerationMapper {

    @Insert(
            """
            INSERT INTO sys_project_generation
                (task_no, project_id, owner_user_id, generation_mode,
                 business_description, ddl_content, generation_status,
                 template_version, created_at, updated_at)
            VALUES (#{taskNo}, #{projectId}, #{ownerUserId}, #{generationMode},
                    #{businessDescription}, #{ddlContent}, 'PENDING',
                    #{templateVersion}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int create(
            @Param("taskNo") String taskNo,
            @Param("projectId") String projectId,
            @Param("ownerUserId") String ownerUserId,
            @Param("generationMode") String generationMode,
            @Param("businessDescription") String businessDescription,
            @Param("ddlContent") String ddlContent,
            @Param("templateVersion") String templateVersion);

    @Select(
            """
            SELECT g.task_no, g.project_id, p.project_code, p.project_name,
                   g.owner_user_id, g.generation_mode, g.business_description,
                   g.ddl_content, g.generation_status, g.template_version,
                   g.blueprint_json, g.ai_model, g.design_summary,
                   g.backend_artifact_name, g.frontend_artifact_name,
                   g.backend_file_manifest, g.frontend_file_manifest, g.last_error,
                   g.started_at, g.completed_at, g.created_at, g.updated_at
            FROM sys_project_generation g
            JOIN sys_project p ON p.id = g.project_id
            WHERE g.task_no = #{taskNo} AND g.owner_user_id = #{ownerUserId}
            """)
    ProjectGenerationJoinRow findOwned(@Param("taskNo") String taskNo, @Param("ownerUserId") String ownerUserId);

    @Select(
            """
            SELECT g.task_no, g.project_id, p.project_code, p.project_name,
                   g.owner_user_id, g.generation_mode, g.business_description,
                   g.ddl_content, g.generation_status, g.template_version,
                   g.blueprint_json, g.ai_model, g.design_summary,
                   g.backend_artifact_name, g.frontend_artifact_name,
                   g.backend_file_manifest, g.frontend_file_manifest, g.last_error,
                   g.started_at, g.completed_at, g.created_at, g.updated_at
            FROM sys_project_generation g
            JOIN sys_project p ON p.id = g.project_id
            WHERE g.task_no = #{taskNo}
            """)
    ProjectGenerationJoinRow find(@Param("taskNo") String taskNo);

    @Select(
            """
            SELECT g.task_no, g.project_id, p.project_code, p.project_name,
                   g.owner_user_id, g.generation_mode, g.business_description,
                   g.ddl_content, g.generation_status, g.template_version,
                   g.blueprint_json, g.ai_model, g.design_summary,
                   g.backend_artifact_name, g.frontend_artifact_name,
                   g.backend_file_manifest, g.frontend_file_manifest, g.last_error,
                   g.started_at, g.completed_at, g.created_at, g.updated_at
            FROM sys_project_generation g
            JOIN sys_project p ON p.id = g.project_id
            WHERE g.project_id = #{projectId} AND g.owner_user_id = #{ownerUserId}
            """)
    ProjectGenerationJoinRow findOwnedByProject(
            @Param("projectId") String projectId, @Param("ownerUserId") String ownerUserId);

    @Select(
            """
            SELECT g.task_no, g.project_id, p.project_code, p.project_name,
                   g.owner_user_id, g.generation_mode, g.business_description,
                   g.ddl_content, g.generation_status, g.template_version,
                   g.blueprint_json, g.ai_model, g.design_summary,
                   g.backend_artifact_name, g.frontend_artifact_name,
                   g.backend_file_manifest, g.frontend_file_manifest, g.last_error,
                   g.started_at, g.completed_at, g.created_at, g.updated_at
            FROM sys_project_generation g
            JOIN sys_project p ON p.id = g.project_id
            WHERE g.owner_user_id = #{ownerUserId}
            ORDER BY g.created_at DESC, g.task_no DESC
            LIMIT 100
            """)
    List<ProjectGenerationJoinRow> listOwned(@Param("ownerUserId") String ownerUserId);

    /** 抢占任务；返回 1 表示本次抢到，靠状态守卫保证同一任务只被一个线程执行。 */
    @Update(
            """
            UPDATE sys_project_generation
            SET generation_status = 'RUNNING', started_at = CURRENT_TIMESTAMP,
                completed_at = NULL, last_error = NULL,
                updated_at = CURRENT_TIMESTAMP
            WHERE task_no = #{taskNo} AND generation_status = 'PENDING'
            """)
    int claim(@Param("taskNo") String taskNo);

    /** 失败后修改输入并重新排队；同时清空上一轮的全部产物字段。 */
    @Update(
            """
            UPDATE sys_project_generation
            SET business_description = #{businessDescription}, ddl_content = #{ddlContent},
                generation_status = 'PENDING',
                blueprint_json = NULL, ai_model = NULL,
                design_summary = NULL,
                backend_artifact_name = NULL,
                frontend_artifact_name = NULL,
                backend_file_manifest = NULL,
                frontend_file_manifest = NULL,
                last_error = NULL, started_at = NULL, completed_at = NULL,
                updated_at = CURRENT_TIMESTAMP
            WHERE task_no = #{taskNo} AND owner_user_id = #{ownerUserId}
              AND generation_status = 'FAILED'
            """)
    int updateAndRetry(
            @Param("taskNo") String taskNo,
            @Param("ownerUserId") String ownerUserId,
            @Param("businessDescription") String businessDescription,
            @Param("ddlContent") String ddlContent);

    @Update(
            """
            UPDATE sys_project_generation
            SET generation_status = 'SUCCESS',
                blueprint_json = #{blueprintJson}, ddl_content = #{ddl}, ai_model = #{aiModel},
                design_summary = #{designSummary}, backend_artifact_name = #{backendArtifact},
                frontend_artifact_name = #{frontendArtifact},
                backend_file_manifest = #{backendManifest},
                frontend_file_manifest = #{frontendManifest}, last_error = NULL,
                completed_at = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
            WHERE task_no = #{taskNo} AND generation_status = 'RUNNING'
            """)
    int markSuccess(
            @Param("taskNo") String taskNo,
            @Param("blueprintJson") String blueprintJson,
            @Param("ddl") String ddl,
            @Param("aiModel") String aiModel,
            @Param("designSummary") String designSummary,
            @Param("backendArtifact") String backendArtifact,
            @Param("frontendArtifact") String frontendArtifact,
            @Param("backendManifest") String backendManifest,
            @Param("frontendManifest") String frontendManifest);

    @Update(
            """
            UPDATE sys_project_generation
            SET generation_status = 'FAILED', last_error = #{error},
                completed_at = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
            WHERE task_no = #{taskNo} AND generation_status = 'RUNNING'
            """)
    int markFailed(@Param("taskNo") String taskNo, @Param("error") String error);

    /** 线程池拒绝发生在 worker 抢占前，只允许补偿仍为 PENDING 的任务。 */
    @Update(
            """
            UPDATE sys_project_generation
            SET generation_status = 'FAILED', last_error = #{error},
                completed_at = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
            WHERE task_no = #{taskNo} AND generation_status = 'PENDING'
            """)
    int markDispatchFailed(@Param("taskNo") String taskNo, @Param("error") String error);

    /** 服务重启后把中断的 RUNNING 任务放回队列。 */
    @Update(
            """
            UPDATE sys_project_generation
            SET generation_status = 'PENDING',
                last_error = '服务重启后已自动重新排队',
                updated_at = CURRENT_TIMESTAMP
            WHERE generation_status = 'RUNNING'
            """)
    int requeueRunning();

    @Select(
            """
            SELECT task_no
            FROM sys_project_generation
            WHERE generation_status = 'PENDING'
            ORDER BY created_at, task_no
            """)
    List<String> pendingTaskNos();

    /** 服务重启中断的推送不能自动重试：远端可能已经不是空仓库了。 */
    @Update(
            """
            UPDATE sys_project_repository
            SET push_status = 'FAILED',
                last_error = '服务重启中断了初始推送，请重新确认远端仍为空后重试',
                updated_at = CURRENT_TIMESTAMP
            WHERE push_status = 'PUSHING'
            """)
    int failInterruptedPushes();

    @Insert(
            """
            INSERT IGNORE INTO sys_project_repository
                (project_id, repository_type, default_branch, push_status,
                 created_at, updated_at)
            VALUES (#{projectId}, #{repositoryType}, #{defaultBranch}, 'NOT_CONFIGURED',
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int ensureRepositoryRow(
            @Param("projectId") String projectId,
            @Param("repositoryType") String repositoryType,
            @Param("defaultBranch") String defaultBranch);

    @Select(
            """
            SELECT project_id, repository_type, gitlab_project_id, web_url,
                   http_clone_url, ssh_clone_url, default_branch, push_status,
                   commit_sha, last_error
            FROM sys_project_repository
            WHERE project_id = #{projectId}
            ORDER BY repository_type
            """)
    List<ProjectRepositoryRow> repositories(@Param("projectId") String projectId);

    @Update(
            """
            UPDATE sys_project_repository
            SET default_branch = #{defaultBranch}, updated_at = CURRENT_TIMESTAMP
            WHERE project_id = #{projectId}
              AND push_status IN ('NOT_CONFIGURED', 'FAILED')
            """)
    int updateUnpushedDefaultBranch(@Param("projectId") String projectId, @Param("defaultBranch") String defaultBranch);

    /** 抢占推送；只有未配置或已失败的仓库能进入 PUSHING，防止并发重复推送。 */
    @Update(
            """
            UPDATE sys_project_repository
            SET push_status = 'PUSHING', last_error = NULL,
                updated_at = CURRENT_TIMESTAMP
            WHERE project_id = #{projectId} AND repository_type = #{repositoryType}
              AND push_status IN ('NOT_CONFIGURED', 'FAILED')
            """)
    int claimPush(@Param("projectId") String projectId, @Param("repositoryType") String repositoryType);

    @Update(
            """
            UPDATE sys_project_repository
            SET gitlab_project_id = #{gitlabProjectId}, web_url = #{webUrl},
                http_clone_url = #{httpCloneUrl}, ssh_clone_url = #{sshCloneUrl},
                updated_at = CURRENT_TIMESTAMP
            WHERE project_id = #{projectId} AND repository_type = #{repositoryType}
            """)
    int saveRemote(
            @Param("projectId") String projectId,
            @Param("repositoryType") String repositoryType,
            @Param("gitlabProjectId") String gitlabProjectId,
            @Param("webUrl") String webUrl,
            @Param("httpCloneUrl") String httpCloneUrl,
            @Param("sshCloneUrl") String sshCloneUrl);

    @Update(
            """
            UPDATE sys_project_repository
            SET push_status = 'PUSHED', commit_sha = #{commitSha}, last_error = NULL,
                updated_at = CURRENT_TIMESTAMP
            WHERE project_id = #{projectId} AND repository_type = #{repositoryType}
              AND push_status = 'PUSHING'
            """)
    int markPushed(
            @Param("projectId") String projectId,
            @Param("repositoryType") String repositoryType,
            @Param("commitSha") String commitSha);

    @Update(
            """
            UPDATE sys_project_repository
            SET push_status = 'FAILED', last_error = #{error},
                updated_at = CURRENT_TIMESTAMP
            WHERE project_id = #{projectId} AND repository_type = #{repositoryType}
              AND push_status = 'PUSHING'
            """)
    int markPushFailed(
            @Param("projectId") String projectId,
            @Param("repositoryType") String repositoryType,
            @Param("error") String error);
}
