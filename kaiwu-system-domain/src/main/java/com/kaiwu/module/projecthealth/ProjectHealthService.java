package com.kaiwu.module.projecthealth;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.gitlab.GitlabApiClient;
import com.kaiwu.module.projectgeneration.ProjectFactoryAccessService;
import com.kaiwu.module.projectgeneration.ProjectGenerationRepository;
import com.kaiwu.module.projectgeneration.ProjectGenerationRepository.RepositoryRow;
import com.kaiwu.module.projectgeneration.ProjectScaffoldGenerator;
import com.kaiwu.module.projecthealth.ProjectHealthEvaluator.RepositorySources;
import com.kaiwu.module.projecthealth.vo.ProjectHealthView;
import com.kaiwu.module.projecthealth.vo.ProjectHealthView.CheckView;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

/**
 * 只读项目体检（ADR 0012）。
 *
 * <p>平台读取业务仓库四个固定的契约面文件，判定工程契约是否仍然完整，只报告不阻断，
 * 永不写入业务仓库。</p>
 */
@Service
public class ProjectHealthService {

    /** ADR 0012 第 1 节固定的读取清单，不得扩展为遍历目录树。 */
    private static final String MANIFEST_PATH = "docs/kaiwu-project-blueprint.json";

    private static final String CI_PATH = ".gitlab-ci.yml";
    private static final String BACKEND_POM_PATH = "pom.xml";
    private static final String FRONTEND_PACKAGE_PATH = "package.json";

    private final ProjectFactoryAccessService accessService;
    private final ProjectGenerationRepository generationRepository;
    private final ProjectHealthRepository healthRepository;
    private final ProjectHealthEvaluator evaluator;
    private final GitlabApiClient gitlabApiClient;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    public ProjectHealthService(
            ProjectFactoryAccessService accessService,
            ProjectGenerationRepository generationRepository,
            ProjectHealthRepository healthRepository,
            ProjectHealthEvaluator evaluator,
            GitlabApiClient gitlabApiClient,
            ObjectMapper objectMapper,
            Clock clock) {
        this.accessService = accessService;
        this.generationRepository = generationRepository;
        this.healthRepository = healthRepository;
        this.evaluator = evaluator;
        this.gitlabApiClient = gitlabApiClient;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    /** 触发一次体检。要求目标项目的 project-admin，与项目工厂同一条授权口径。 */
    public ProjectHealthView check(String projectId, String userId) {
        accessService.requireProjectAdmin(projectId, userId);
        if (!healthRepository.healthCheckEnabled(projectId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "该项目已关闭只读体检", "api.projectHealth.disabled");
        }
        RepositorySources sources = readSources(projectId);
        List<CheckView> checks = evaluator.evaluate(
                sources, ProjectScaffoldGenerator.TEMPLATE_VERSION, ProjectScaffoldGenerator.STARTER_VERSION);
        String verdict = evaluator.summarize(checks);
        LocalDateTime checkedAt = LocalDateTime.now(clock);
        healthRepository.save(projectId, verdict, objectMapper.writeValueAsString(checks), checkedAt);
        return new ProjectHealthView(projectId, true, verdict, checkedAt, checks);
    }

    /**
     * 读取体检状态。
     *
     * <p>即使从未体检过也返回视图（{@code checkedAt} 为 null），因为界面上的体检开关需要
     * 真实状态——只在有报告时才返回，会让已关闭体检的项目在界面上显示为开启。</p>
     */
    public ProjectHealthView latest(String projectId, String userId) {
        accessService.requireProjectAdmin(projectId, userId);
        boolean enabled = healthRepository.healthCheckEnabled(projectId);
        return healthRepository
                .latest(projectId)
                .map(report -> new ProjectHealthView(
                        projectId,
                        enabled,
                        report.verdict(),
                        report.checkedAt(),
                        objectMapper.readValue(report.checksJson(), new TypeReference<List<CheckView>>() {})))
                .orElseGet(() -> new ProjectHealthView(projectId, enabled, "UNKNOWN", null, List.of()));
    }

    public void setEnabled(String projectId, String userId, boolean enabled) {
        accessService.requireProjectAdmin(projectId, userId);
        healthRepository.setHealthCheckEnabled(projectId, enabled);
    }

    /**
     * 逐仓读取契约面文件。
     *
     * <p>仓库未绑定或未成功推送时标记为不可读，而不是把缺文件当成 FAIL——
     * 只下载 ZIP 自行托管的项目平台本来就看不到，不能因此判定它不合格。</p>
     */
    private RepositorySources readSources(String projectId) {
        List<RepositoryRow> repositories = generationRepository.repositories(projectId);
        RepositoryRow backend = pick(repositories, "BACKEND");
        RepositoryRow frontend = pick(repositories, "FRONTEND");
        boolean backendReadable = readable(backend);
        boolean frontendReadable = readable(frontend);
        return new RepositorySources(
                backendReadable,
                frontendReadable,
                backendReadable ? read(backend, MANIFEST_PATH) : Optional.empty(),
                backendReadable ? read(backend, CI_PATH) : Optional.empty(),
                backendReadable ? read(backend, BACKEND_POM_PATH) : Optional.empty(),
                frontendReadable ? read(frontend, FRONTEND_PACKAGE_PATH) : Optional.empty());
    }

    private RepositoryRow pick(List<RepositoryRow> repositories, String type) {
        return repositories.stream()
                .filter(row -> type.equals(row.repositoryType()))
                .findFirst()
                .orElse(null);
    }

    private boolean readable(RepositoryRow row) {
        return row != null && StringUtils.hasText(row.gitlabProjectId()) && "SUCCESS".equals(row.pushStatus());
    }

    private Optional<String> read(RepositoryRow row, String path) {
        return gitlabApiClient.readTextFile(row.gitlabProjectId(), row.defaultBranch(), path);
    }
}
