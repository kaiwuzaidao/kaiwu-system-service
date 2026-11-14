package com.kaiwu.module.factory.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.factory.renderer.ProjectScaffoldGenerator;
import com.kaiwu.module.factory.renderer.ProjectScaffoldGenerator.GeneratedModule;
import com.kaiwu.module.factory.renderer.ProjectScaffoldGenerator.GeneratedRepositories;
import com.kaiwu.module.factory.repository.ProjectGenerationRepository;
import com.kaiwu.module.factory.repository.ProjectGenerationRepository.GenerationRow;
import com.kaiwu.module.factory.service.CodegenArtifactService;
import com.kaiwu.module.factory.service.ProjectBlueprintService;
import com.kaiwu.module.factory.service.ProjectGenerationService;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationCreateRequest;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationRetryRequest;
import com.kaiwu.module.projectgeneration.vo.ProjectGenerationInputView;
import com.kaiwu.module.projectgeneration.vo.ProjectGenerationView;
import com.kaiwu.port.ProjectGenerationProjectPort;
import com.kaiwu.port.UserNotificationPort;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Executor;
import java.util.concurrent.RejectedExecutionException;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.util.StringUtils;

/**
 * 一项目一次的异步项目生成；产物以 ZIP 下载，不再推送 Git 服务（ADR 0038）。
 */
@Service("projectGenerationService")
public class ProjectGenerationServiceImpl implements ProjectGenerationService {

    private final ProjectGenerationRepository repository;
    private final ProjectGenerationProjectPort projects;
    private final ProjectBlueprintService blueprintService;
    private final ProjectScaffoldGenerator scaffoldGenerator;
    private final CodegenArtifactService artifactService;
    private final UserNotificationPort notificationService;
    private final TransactionTemplate transactionTemplate;
    private final Executor executor;

    public ProjectGenerationServiceImpl(
            ProjectGenerationRepository repository,
            ProjectGenerationProjectPort projects,
            ProjectBlueprintService blueprintService,
            ProjectScaffoldGenerator scaffoldGenerator,
            CodegenArtifactService artifactService,
            UserNotificationPort notificationService,
            TransactionTemplate transactionTemplate,
            @Qualifier("projectGenerationExecutor") Executor executor) {
        this.repository = repository;
        this.projects = projects;
        this.blueprintService = blueprintService;
        this.scaffoldGenerator = scaffoldGenerator;
        this.artifactService = artifactService;
        this.notificationService = notificationService;
        this.transactionTemplate = transactionTemplate;
        this.executor = executor;
    }

    /**
     * 提交一次项目生成。
     *
     * <p>每个项目只允许成功生成一次（CLAUDE.md 工程约束第 11 条），因此这里以
     * {@code project_id} 唯一约束兜底；任务入库为 PENDING，由后台线程抢占执行。</p>
     */
    public ProjectGenerationView create(ProjectGenerationCreateRequest request, String ownerUserId) {
        requireSupportedMode(request.generationMode());
        ProjectView project = projects.requireProjectAdmin(request.projectId(), ownerUserId);
        if ("BASIC_SCAFFOLD".equals(request.generationMode())
                && (StringUtils.hasText(request.ddl()) || StringUtils.hasText(request.businessDescription()))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "基础脚手架不接收业务描述或 DDL，业务功能请在生成后开发", "api.common.badRequest");
        }
        String taskNo = "PG-" + System.currentTimeMillis() + "-"
                + UUID.randomUUID().toString().substring(0, 8);
        GenerationRow row = new GenerationRow(
                taskNo,
                project.id(),
                project.projectCode(),
                project.projectName(),
                ownerUserId,
                request.generationMode(),
                normalize(request.businessDescription()),
                normalize(request.ddl()),
                "PENDING",
                ProjectScaffoldGenerator.TEMPLATE_VERSION,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null);
        try {
            repository.create(row);
        } catch (DuplicateKeyException exception) {
            throw new ApiException(HttpStatus.CONFLICT, "该项目已经创建过项目工厂任务；失败任务请使用重试，成功项目不能再次生成", "api.common.conflict");
        }
        enqueue(taskNo);
        return toView(requireOwned(taskNo, ownerUserId));
    }

    /** 当前用户发起过的生成任务，最多 100 条，可按项目收窄。 */
    public List<ProjectGenerationView> list(String ownerUserId, String projectId) {
        if (StringUtils.hasText(projectId)) {
            return repository
                    .findOwnedByProject(projectId, ownerUserId)
                    .map(row -> List.of(toView(row)))
                    .orElseGet(List::of);
        }
        return repository.listOwned(ownerUserId).stream().map(this::toView).toList();
    }

    public ProjectGenerationView get(String taskNo, String ownerUserId) {
        return toView(requireOwned(taskNo, ownerUserId));
    }

    /** 取回失败任务的原始输入，供用户修改后重试；只有任务发起人能看。 */
    public ProjectGenerationInputView editableInput(String taskNo, String ownerUserId) {
        GenerationRow row = requireOwned(taskNo, ownerUserId);
        projects.requireProjectAdmin(row.projectId(), ownerUserId);
        if (!"FAILED".equals(row.status())) {
            throw new ApiException(HttpStatus.CONFLICT, "只有失败任务可以修改输入后重试", "api.common.conflict");
        }
        return new ProjectGenerationInputView(
                row.taskNo(),
                row.projectId(),
                row.projectName(),
                row.generationMode(),
                row.businessDescription(),
                row.ddlContent());
    }

    /**
     * 修改输入并重新排队。
     *
     * <p>只有 FAILED 状态可重试，且会清空上一轮的全部产物字段——留着旧蓝图会让人
     * 以为重试成功了却下载到上一次的包。</p>
     */
    public ProjectGenerationView retry(String taskNo, ProjectGenerationRetryRequest request, String ownerUserId) {
        GenerationRow row = requireOwned(taskNo, ownerUserId);
        requireSupportedMode(row.generationMode());
        projects.requireProjectAdmin(row.projectId(), ownerUserId);
        String businessDescription =
                request == null ? row.businessDescription() : normalize(request.businessDescription());
        String ddl = request == null ? row.ddlContent() : normalize(request.ddl());
        if ("BASIC_SCAFFOLD".equals(row.generationMode())
                && (StringUtils.hasText(ddl) || StringUtils.hasText(businessDescription))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "基础脚手架不接收业务描述或 DDL", "api.common.badRequest");
        }
        if (!repository.updateAndRetry(taskNo, ownerUserId, businessDescription, ddl)) {
            throw new ApiException(HttpStatus.CONFLICT, "只有失败任务可以重试；成功项目不能再次生成", "api.common.conflict");
        }
        enqueue(taskNo);
        return toView(requireOwned(taskNo, ownerUserId));
    }

    /** 只允许新建或重试基础脚手架；历史任务仍可查看和下载。 */
    private static void requireSupportedMode(String generationMode) {
        if (!"BASIC_SCAFFOLD".equals(generationMode)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "该生成模式已下线，请使用基础脚手架", "api.common.badRequest");
        }
    }

    /** 下载生成产物；只有任务发起人可下载，且任务必须已 SUCCESS。 */
    public Download download(String taskNo, String repositoryType, String ownerUserId) {
        GenerationRow row = requireOwned(taskNo, ownerUserId);
        if (!"SUCCESS".equals(row.status())) {
            throw new ApiException(HttpStatus.CONFLICT, "项目生成成功后才能下载", "api.common.conflict");
        }
        String type = normalizeType(repositoryType);
        String artifactName = "BACKEND".equals(type) ? row.backendArtifactName() : row.frontendArtifactName();
        if (!StringUtils.hasText(artifactName)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "生成制品不存在", "api.common.notFound");
        }
        return new Download(artifactName, artifactService.resource(artifactName));
    }

    public void enqueue(String taskNo) {
        try {
            executor.execute(() -> generate(taskNo));
        } catch (RejectedExecutionException exception) {
            repository.markDispatchFailed(taskNo, "项目生成执行队列已满，请稍后重试");
            throw dispatchUnavailable("项目生成执行队列已满，请稍后重试", exception);
        }
    }

    private ApiException dispatchUnavailable(String message, RejectedExecutionException cause) {
        ApiException exception =
                new ApiException(HttpStatus.SERVICE_UNAVAILABLE, message, "api.common.serviceUnavailable");
        exception.initCause(cause);
        return exception;
    }

    private void generate(String taskNo) {
        if (!repository.claim(taskNo)) return;
        GenerationRow row = repository.find(taskNo).orElse(null);
        if (row == null) return;
        String backendArtifact = null;
        String frontendArtifact = null;
        try {
            ProjectView project = projects.requireProjectAdmin(row.projectId(), row.ownerUserId());
            ProjectGenerationCreateRequest request = new ProjectGenerationCreateRequest(
                    row.projectId(), row.generationMode(),
                    row.businessDescription(), row.ddlContent());
            ProjectBlueprintService.ProjectBlueprint blueprint = blueprintService.create(project, request);
            GeneratedRepositories generated = scaffoldGenerator.generate(project, blueprint);
            backendArtifact = artifactService.createProjectArtifact(
                    taskNo, "BACKEND", project.projectCode(), generated.backendFiles());
            frontendArtifact = artifactService.createProjectArtifact(
                    taskNo, "FRONTEND", project.projectCode(), generated.frontendFiles());
            String finalBackendArtifact = backendArtifact;
            String finalFrontendArtifact = frontendArtifact;
            transactionTemplate.executeWithoutResult(status -> {
                repository.markSuccess(
                        taskNo,
                        blueprint,
                        finalBackendArtifact,
                        finalFrontendArtifact,
                        manifest(generated.backendFiles()),
                        manifest(generated.frontendFiles()));
                registerProjectMenus(project, generated.modules());
            });
            // 站内信是尽力而为的通知，写入失败已在 Service 内部降级为日志。
            notificationService.notifyUser(
                    row.ownerUserId(),
                    "TASK",
                    project.projectName() + " 生成成功",
                    "第一版后端与前端仓库已生成，请下载 ZIP，再用 AI 工具继续开发。",
                    "/project-factory");
        } catch (Exception exception) {
            if (backendArtifact != null) {
                artifactService.deleteQuietly(backendArtifact);
            }
            if (frontendArtifact != null) {
                artifactService.deleteQuietly(frontendArtifact);
            }
            String error = safeError(exception);
            repository.markFailed(taskNo, error);
            notificationService.notifyUser(row.ownerUserId(), "TASK", "项目生成失败", error, "/project-factory");
        }
    }

    private void registerProjectMenus(ProjectView project, List<GeneratedModule> modules) {
        for (GeneratedModule module : modules) {
            String menuId = Long.toString(stableId(project.id() + ":" + module.permissionPrefix() + ":menu"));
            String actualMenuId = projects.upsertGeneratedMenu(
                    menuId,
                    project.id(),
                    null,
                    module.moduleName(),
                    "MENU",
                    "/" + module.moduleCode(),
                    module.moduleCode() + "/" + module.table().getEntityName(),
                    null,
                    0);
            projects.grantMenuToAdmin(project.id(), actualMenuId);
            registerButton(project.id(), actualMenuId, module.permissionPrefix(), "list", "查询", 10);
            registerButton(project.id(), actualMenuId, module.permissionPrefix(), "save", "新增/编辑", 20);
            registerButton(project.id(), actualMenuId, module.permissionPrefix(), "delete", "删除", 30);
        }
    }

    private void registerButton(
            String projectId, String parentId, String prefix, String action, String name, int sortNo) {
        String permission = prefix + ":" + action;
        String menuId = Long.toString(stableId(projectId + ":" + permission));
        String actualId = projects.upsertGeneratedMenu(
                menuId, projectId, parentId, name, "BUTTON", null, null, permission, sortNo);
        projects.grantMenuToAdmin(projectId, actualId);
    }

    private GenerationRow requireOwned(String taskNo, String ownerUserId) {
        return repository
                .findOwned(taskNo, ownerUserId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目生成任务不存在", "api.common.notFound"));
    }

    private ProjectGenerationView toView(GenerationRow row) {
        return new ProjectGenerationView(
                row.taskNo(),
                row.projectId(),
                row.projectCode(),
                row.projectName(),
                row.generationMode(),
                row.status(),
                row.aiModel(),
                row.designSummary(),
                row.templateVersion(),
                lines(row.backendFileManifest()),
                lines(row.frontendFileManifest()),
                row.lastError(),
                row.startedAt(),
                row.completedAt(),
                row.createdAt(),
                row.updatedAt());
    }

    private List<String> lines(String value) {
        return StringUtils.hasText(value) ? value.lines().toList() : List.of();
    }

    private String manifest(Map<String, String> files) {
        return files.keySet().stream()
                .sorted()
                .reduce((left, right) -> left + "\n" + right)
                .orElse("");
    }

    private String normalizeType(String value) {
        String type = value == null ? "" : value.trim().toUpperCase(Locale.ROOT);
        if (!List.of("BACKEND", "FRONTEND").contains(type)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "制品类型只支持 BACKEND 或 FRONTEND", "api.common.badRequest");
        }
        return type;
    }

    private String safeError(Exception exception) {
        if (exception instanceof ApiException && StringUtils.hasText(exception.getMessage())) {
            return exception.getMessage();
        }
        return "项目工厂执行失败，请检查输入和平台配置后重试";
    }

    private static String normalize(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }

    private static long stableId(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            long raw = 0L;
            for (int index = 0; index < Long.BYTES; index++) {
                raw = (raw << 8) | (digest[index] & 0xffL);
            }
            long positive = raw == Long.MIN_VALUE ? 0 : Math.abs(raw);
            return 8_000_000_000_000_000_000L + positive % 1_000_000_000_000_000_000L;
        } catch (Exception exception) {
            throw new IllegalStateException("SHA-256 unavailable", exception);
        }
    }
}
