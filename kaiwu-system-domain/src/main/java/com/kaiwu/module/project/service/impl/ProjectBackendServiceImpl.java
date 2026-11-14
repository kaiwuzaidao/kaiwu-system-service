package com.kaiwu.module.project.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.model.GatewayRouteFragment;
import com.kaiwu.module.project.repository.ProjectBackendServiceRepository;
import com.kaiwu.module.project.repository.ProjectRepository;
import com.kaiwu.module.project.service.ProjectBackendService;
import com.kaiwu.module.project.vo.BackendServiceView;
import com.kaiwu.module.project.vo.GatewayRoutesView;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.starter.KaiwuContext;
import java.net.URI;
import java.util.List;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** 强制平台权限之外的目标项目管理员身份与服务地址安全规则。 */
@Service
public class ProjectBackendServiceImpl implements ProjectBackendService {
    private final ProjectBackendServiceRepository services;
    private final ProjectRepository projects;
    private final AuditPort audit;
    private final boolean multiEnabled;
    /** 接受默认关闭的混合版本保护开关。 */
    public ProjectBackendServiceImpl(
            ProjectBackendServiceRepository services,
            ProjectRepository projects,
            AuditPort audit,
            @Value("${kaiwu.project-backend-services.multi-enabled:false}") boolean multiEnabled) {
        this.services = services;
        this.projects = projects;
        this.audit = audit;
        this.multiEnabled = multiEnabled;
    }

    /** 平台权限之外复核目标项目管理员，只返回本项目服务元数据。 */
    @Override
    public List<BackendServiceView> list(String projectId, KaiwuContext actor) {
        authorize(projectId, actor);
        return services.list(projectId);
    }

    /** 默认关闭期间拒绝多服务写入；启用后在项目锁内登记规范服务并同事务审计。 */
    @Override
    @Transactional
    public BackendServiceView create(
            String projectId, String code, String url, KaiwuContext actor, RequestMetadata metadata) {
        requireEnabled();
        var project = authorize(projectId, actor);
        validateCode(code);
        if ("default".equals(code)) throw badRequest();
        String target = validateUrl(url, false);
        if (!services.lockProject(projectId)) throw notFound();
        requireConsistentDefault(projectId, project);
        try {
            services.insert(projectId, code, target);
        } catch (DuplicateKeyException ex) {
            throw new ApiException(HttpStatus.CONFLICT, "服务编码已存在", "api.project.backendServiceConflict");
        }
        audit(actor, projectId, code, "CREATE_BACKEND_SERVICE", metadata);
        return requireService(projectId, code);
    }

    /** 修改default时同步旧字段与新登记，非default必须经过混合版本保护。 */
    @Override
    @Transactional
    public BackendServiceView updateUrl(
            String projectId, String code, String url, KaiwuContext actor, RequestMetadata metadata) {
        var project = authorize(projectId, actor);
        validateCode(code);
        if (!"default".equals(code)) requireEnabled();
        String target = validateUrl(url, "default".equals(code));
        if (!services.lockProject(projectId)) throw notFound();
        if (!"default".equals(code)) requireConsistentDefault(projectId, project);
        var old = requireService(projectId, code);
        if (!java.util.Objects.equals(old.serviceUrl(), target)) {
            services.updateUrl(projectId, code, target);
            audit(actor, projectId, code, "UPDATE_BACKEND_SERVICE", metadata);
        }
        return requireService(projectId, code);
    }

    /** 只控制后续导出的服务状态，已发布路由由运维另行审核撤销。 */
    @Override
    @Transactional
    public BackendServiceView updateStatus(
            String projectId, String code, String status, KaiwuContext actor, RequestMetadata metadata) {
        requireEnabled();
        var project = authorize(projectId, actor);
        validateCode(code);
        if (status == null || !Set.of("ENABLED", "DISABLED").contains(status)) throw badRequest();
        if (!services.lockProject(projectId)) throw notFound();
        requireConsistentDefault(projectId, project);
        var old = requireService(projectId, code);
        if (!old.status().equals(status)) {
            services.updateStatus(projectId, code, status);
            audit(
                    actor,
                    projectId,
                    code,
                    "ENABLED".equals(status) ? "ENABLE_BACKEND_SERVICE" : "DISABLE_BACKEND_SERVICE",
                    metadata);
        }
        return requireService(projectId, code);
    }

    /** 关闭模式沿用旧字段，开启模式先核对default再导出各自隔离的启用片段。 */
    @Override
    @Transactional(readOnly = true)
    public GatewayRoutesView routes(String projectId, KaiwuContext actor) {
        ProjectView project = authorize(projectId, actor);
        if (!multiEnabled) {
            return new GatewayRoutesView(
                    project.serviceUrl() == null || project.serviceUrl().isBlank()
                            ? List.of()
                            : List.of(new GatewayRoutesView.Fragment("default", GatewayRouteFragment.render(project))));
        }
        requireConsistentDefault(projectId, project);
        var fragments = services.list(projectId).stream()
                .filter(s -> (multiEnabled || "default".equals(s.serviceCode()))
                        && "ENABLED".equals(s.status())
                        && s.serviceUrl() != null
                        && !s.serviceUrl().isBlank())
                .map(s -> new GatewayRoutesView.Fragment(
                        s.serviceCode(),
                        "default".equals(s.serviceCode())
                                ? GatewayRouteFragment.render(project)
                                : render(project.projectCode(), s)))
                .toList();
        return new GatewayRoutesView(fragments);
    }

    /** 混合版本或回填不一致时拒绝生成和修改非默认服务。 */
    private void requireConsistentDefault(String projectId, ProjectView project) {
        var current = services.find(projectId, "default");
        if (current.isEmpty() || !java.util.Objects.equals(current.get().serviceUrl(), project.serviceUrl())) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "默认服务地址尚未完成核对", "api.common.serviceUnavailable");
        }
    }

    /** 平台权限之外必须是目标项目有效管理员，内置system项目不接受业务服务登记。 */
    private ProjectView authorize(String projectId, KaiwuContext actor) {
        var project = projects.findProject(projectId).orElseThrow(ProjectBackendServiceImpl::notFound);
        if (project.builtIn()) throw badRequest();
        if (actor == null
                || !projects.activeMemberExists(projectId, actor.userId())
                || !projects.findCurrentRoleCodes(projectId, actor.userId()).contains("project-admin"))
            throw new ApiException(HttpStatus.FORBIDDEN, "不是目标项目管理员", "api.common.forbidden");
        return project;
    }

    /** 混合版本保护默认关闭，旧实例未退出前不允许新增或启停多服务。 */
    private void requireEnabled() {
        if (!multiEnabled)
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "多服务登记尚未启用", "api.common.serviceUnavailable");
    }

    /** 服务编码用于路径与audience推导，拒绝大小写别名及不规范标识。 */
    private static void validateCode(String code) {
        if (code == null || !code.matches("[a-z][a-z0-9]{1,15}")) throw badRequest();
    }

    /** 上游只接受无凭据、路径、query或片段的可信配置原点；default允许清空。 */
    private static String validateUrl(String url, boolean nullable) {
        if (url == null || url.isBlank()) {
            if (nullable) return null;
            throw badRequest();
        }
        if (url.length() > 512 || !url.equals(url.trim()) || url.contains("\\n") || url.contains("\\r"))
            throw badRequest();
        try {
            URI uri = URI.create(url);
            if (uri.getScheme() == null
                    || !Set.of("http", "https", "lb").contains(uri.getScheme())
                    || uri.getHost() == null
                    || uri.getUserInfo() != null
                    || uri.getQuery() != null
                    || uri.getFragment() != null
                    || !(uri.getPath().isEmpty() || uri.getPath().equals("/"))) throw badRequest();
            return url;
        } catch (IllegalArgumentException ex) {
            throw badRequest();
        }
    }

    /** 只能在授权项目内查找已登记服务，不因同编码读取其他项目。 */
    private BackendServiceView requireService(String projectId, String code) {
        return services.find(projectId, code).orElseThrow(ProjectBackendServiceImpl::notFound);
    }

    /** 审计与地址/状态变更同事务，仅记录项目和服务编码，不记录敏感信息。 */
    private void audit(KaiwuContext actor, String projectId, String code, String operation, RequestMetadata metadata) {
        audit.recordOperationInCallerTransaction(
                actor,
                "project",
                operation,
                "/api/projects/" + projectId + "/backend-services",
                "projectId=" + projectId + ",serviceCode=" + code,
                metadata);
    }

    /** 非default片段从规范项目和服务事实推导，文本仅供审查，不自动写配置中心。 */
    private static String render(String p, BackendServiceView s) {
        String code = s.serviceCode();
        return "- id: " + p + "." + code + "-project\n  uri: " + s.serviceUrl() + "\n  predicates:\n    - Path=/" + p
                + "-svc/" + code + "/**\n  filters:\n    - RewritePath=/" + p + "-svc/" + code
                + "/(?<segment>.*), /${segment}\n  metadata:\n    accessMode: PROJECT\n    audience: kaiwu-" + p + "."
                + code + "-service\n    projectCode: " + p + "\n    serviceCode: " + code + "\n";
    }

    /** 无效输入整体拒绝，禁止产生部分登记或不受控YAML。 */
    private static ApiException badRequest() {
        return new ApiException(HttpStatus.BAD_REQUEST, "请求参数无效", "api.common.badRequest");
    }

    /** 隐藏其他项目事实，缺失项目或服务使用相同404协议。 */
    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "项目或服务不存在", "api.common.notFound");
    }
}
