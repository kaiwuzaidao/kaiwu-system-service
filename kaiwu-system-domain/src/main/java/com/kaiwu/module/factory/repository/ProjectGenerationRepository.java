package com.kaiwu.module.factory.repository;

import com.kaiwu.module.factory.entity.ProjectGenerationJoinRow;
import com.kaiwu.module.factory.mapper.ProjectGenerationMapper;
import com.kaiwu.module.factory.service.ProjectBlueprintService;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Repository;

@Repository
public class ProjectGenerationRepository {

    private static final int MAX_GENERATION_ERROR_LENGTH = 2000;

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
}
