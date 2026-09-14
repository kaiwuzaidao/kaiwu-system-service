package com.kaiwu.module.projectgeneration;

import com.kaiwu.module.projectgeneration.entity.ProjectGenerationJoinRow;
import com.kaiwu.module.projectgeneration.entity.ProjectRepositoryRow;
import com.kaiwu.module.projectgeneration.mapper.ProjectGenerationMapper;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Repository;

@Repository
public class ProjectGenerationRepository {

    private static final int MAX_GENERATION_ERROR_LENGTH = 2000;
    private static final int MAX_PUSH_ERROR_LENGTH = 1000;

    private final ProjectGenerationMapper mapper;

    public ProjectGenerationRepository(ProjectGenerationMapper mapper) {
        this.mapper = mapper;
    }

    public void create(GenerationRow row) {
        mapper.create(
                row.taskNo(),
                row.projectId(),
                row.ownerUserId(),
                row.generationMode(),
                row.businessDescription(),
                row.ddlContent(),
                row.templateVersion());
    }

    public Optional<GenerationRow> findOwned(String taskNo, String ownerUserId) {
        return Optional.ofNullable(mapper.findOwned(taskNo, ownerUserId)).map(ProjectGenerationRepository::toRow);
    }

    public Optional<GenerationRow> find(String taskNo) {
        return Optional.ofNullable(mapper.find(taskNo)).map(ProjectGenerationRepository::toRow);
    }

    public Optional<GenerationRow> findOwnedByProject(String projectId, String ownerUserId) {
        return Optional.ofNullable(mapper.findOwnedByProject(projectId, ownerUserId))
                .map(ProjectGenerationRepository::toRow);
    }

    public List<GenerationRow> listOwned(String ownerUserId) {
        return mapper.listOwned(ownerUserId).stream()
                .map(ProjectGenerationRepository::toRow)
                .toList();
    }

    public boolean claim(String taskNo) {
        return mapper.claim(taskNo) == 1;
    }

    public boolean updateAndRetry(String taskNo, String ownerUserId, String businessDescription, String ddlContent) {
        return mapper.updateAndRetry(taskNo, ownerUserId, businessDescription, ddlContent) == 1;
    }

    /** 标记生成成功并写入蓝图与产物信息；带 RUNNING 守卫，防止非执行者回写。 */
    public void markSuccess(
            String taskNo,
            ProjectBlueprintService.ProjectBlueprint blueprint,
            String backendArtifact,
            String frontendArtifact,
            String backendManifest,
            String frontendManifest) {
        mapper.markSuccess(
                taskNo,
                blueprint.json(),
                blueprint.ddl(),
                blueprint.aiModel(),
                blueprint.designSummary(),
                backendArtifact,
                frontendArtifact,
                backendManifest,
                frontendManifest);
    }

    public void markFailed(String taskNo, String error) {
        mapper.markFailed(taskNo, abbreviate(error, MAX_GENERATION_ERROR_LENGTH));
    }

    /** 执行器拒绝发生在任务抢占前，只补偿仍为 PENDING 的记录。 */
    public void markDispatchFailed(String taskNo, String error) {
        mapper.markDispatchFailed(taskNo, abbreviate(error, MAX_GENERATION_ERROR_LENGTH));
    }

    /** 服务重启后把中断的任务放回队列，并返回当前所有待执行任务号。 */
    public List<String> recoverableTaskNos() {
        mapper.requeueRunning();
        return mapper.pendingTaskNos();
    }

    public void recoverInterruptedPushes() {
        mapper.failInterruptedPushes();
    }

    public void ensureRepositoryRows(String projectId, String defaultBranch) {
        for (String type : List.of("BACKEND", "FRONTEND")) {
            mapper.ensureRepositoryRow(projectId, type, defaultBranch);
        }
    }

    public List<RepositoryRow> repositories(String projectId) {
        return mapper.repositories(projectId).stream()
                .map(ProjectGenerationRepository::toRow)
                .toList();
    }

    public void updateUnpushedDefaultBranch(String projectId, String defaultBranch) {
        mapper.updateUnpushedDefaultBranch(projectId, defaultBranch);
    }

    public boolean claimPush(String projectId, String type) {
        return mapper.claimPush(projectId, type) == 1;
    }

    public void saveRemote(
            String projectId,
            String type,
            String gitlabProjectId,
            String webUrl,
            String httpCloneUrl,
            String sshCloneUrl) {
        mapper.saveRemote(projectId, type, gitlabProjectId, webUrl, httpCloneUrl, sshCloneUrl);
    }

    public void markPushed(String projectId, String type, String commitSha) {
        mapper.markPushed(projectId, type, commitSha);
    }

    public void markPushFailed(String projectId, String type, String error) {
        mapper.markPushFailed(projectId, type, abbreviate(error, MAX_PUSH_ERROR_LENGTH));
    }

    private static GenerationRow toRow(ProjectGenerationJoinRow row) {
        return new GenerationRow(
                row.getTaskNo(),
                row.getProjectId(),
                row.getProjectCode(),
                row.getProjectName(),
                row.getOwnerUserId(),
                row.getGenerationMode(),
                row.getBusinessDescription(),
                row.getDdlContent(),
                row.getGenerationStatus(),
                row.getTemplateVersion(),
                row.getBlueprintJson(),
                row.getAiModel(),
                row.getDesignSummary(),
                row.getBackendArtifactName(),
                row.getFrontendArtifactName(),
                row.getBackendFileManifest(),
                row.getFrontendFileManifest(),
                row.getLastError(),
                row.getStartedAt(),
                row.getCompletedAt(),
                row.getCreatedAt(),
                row.getUpdatedAt());
    }

    private static RepositoryRow toRow(ProjectRepositoryRow row) {
        return new RepositoryRow(
                row.getProjectId(),
                row.getRepositoryType(),
                row.getGitlabProjectId(),
                row.getWebUrl(),
                row.getHttpCloneUrl(),
                row.getSshCloneUrl(),
                row.getDefaultBranch(),
                row.getPushStatus(),
                row.getCommitSha(),
                row.getLastError());
    }

    private static String abbreviate(String value, int max) {
        if (value == null || value.length() <= max) return value;
        return value.substring(0, max);
    }

    public record GenerationRow(
            String taskNo,
            String projectId,
            String projectCode,
            String projectName,
            String ownerUserId,
            String generationMode,
            String businessDescription,
            String ddlContent,
            String status,
            String templateVersion,
            String blueprintJson,
            String aiModel,
            String designSummary,
            String backendArtifactName,
            String frontendArtifactName,
            String backendFileManifest,
            String frontendFileManifest,
            String lastError,
            LocalDateTime startedAt,
            LocalDateTime completedAt,
            LocalDateTime createdAt,
            LocalDateTime updatedAt) {}

    public record RepositoryRow(
            String projectId,
            String repositoryType,
            String gitlabProjectId,
            String webUrl,
            String httpCloneUrl,
            String sshCloneUrl,
            String defaultBranch,
            String pushStatus,
            String commitSha,
            String lastError) {}
}
