package com.kaiwu.module.agent.execution;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageResult;
import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.agent.planning.PlanRejectedException;
import com.kaiwu.module.agent.presentation.CardProjection;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.CapabilityResult;
import com.kaiwu.module.configuration.service.I18nService;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.connector.service.AiProviderService;
import com.kaiwu.module.factory.service.ProjectGenerationService;
import com.kaiwu.module.identity.service.OrgService;
import com.kaiwu.module.identity.service.UserService;
import com.kaiwu.module.operation.service.LogCenterService;
import com.kaiwu.module.operation.service.ProjectSchedulerService;
import com.kaiwu.module.org.vo.DepartmentView;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.vo.ProjectMenuView;
import com.kaiwu.starter.KaiwuContext;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * 把校验通过的调用接到控制面已有的 Service。
 *
 * <p>调用**必须复现 Controller 的全部收窄参数**：可见性收窄发生在 Service 内部，
 * 依赖传入的 Context 或 userId。本类是 in-process 调用，不经过 Controller，
 * 漏传就等于越权（ADR 0030 第 4 条）。每接一条新能力都要核对被调方法的签名。</p>
 *
 * <p>单条能力失败不拖垮整体：记下该条失败，其余结果照常返回，
 * 由上层置 {@code PARTIAL_CAPABILITY_FAILURE}。这是「单项目不可达不影响其余项目」
 * 在 P1a 的小型预演，现在做对，P2 就不用返工。</p>
 */
@Component
public class CapabilityInvoker {

    private static final Logger log = LoggerFactory.getLogger(CapabilityInvoker.class);

    private RemoteCapabilityInvoker remote;

    @org.springframework.beans.factory.annotation.Autowired
    public void remoteInvoker(RemoteCapabilityInvoker value) {
        remote = value;
    }

    private final ProjectService projectService;
    private final ProjectGenerationService generationService;
    private final ProjectSchedulerService schedulerService;
    private final UserService userService;
    private final OrgService orgService;
    private final MetadataService metadataService;
    private final LogCenterService logCenterService;
    private final AiProviderService aiProviderService;
    private final I18nService i18nService;

    public CapabilityInvoker(
            ProjectService projectService,
            ProjectGenerationService generationService,
            ProjectSchedulerService schedulerService,
            UserService userService,
            OrgService orgService,
            MetadataService metadataService,
            LogCenterService logCenterService,
            AiProviderService aiProviderService,
            I18nService i18nService) {
        this.projectService = projectService;
        this.generationService = generationService;
        this.schedulerService = schedulerService;
        this.userService = userService;
        this.orgService = orgService;
        this.metadataService = metadataService;
        this.logCenterService = logCenterService;
        this.aiProviderService = aiProviderService;
        this.i18nService = i18nService;
    }

    public CapabilityResult invoke(Capability capability, Map<String, Object> params, KaiwuContext actor) {
        return invoke(capability, params, actor, java.util.UUID.randomUUID().toString());
    }

    public CapabilityResult invoke(
            Capability capability, Map<String, Object> params, KaiwuContext actor, String correlationId) {
        try {
            if (!Capability.SYSTEM_PROJECT_CODE.equals(capability.projectCode())) {
                if (remote == null) throw new PlanRejectedException(3, "远程能力不可用");
                return remote.invoke(capability, params, actor, correlationId);
            }
            // 本地能力也要在执行入口复核当前主体，不能只依赖规划前的目录裁剪。
            if (actor == null || !actor.hasPermission(capability.permission()))
                throw new PlanRejectedException(3, "无权限操作");
            return switch (capability.code()) {
                case CapabilityCatalog.PROJECT_LIST -> projects(params);
                case CapabilityCatalog.PROJECT_DETAIL -> projectDetail(params);
                case CapabilityCatalog.GENERATION_LIST -> generations(params, actor);
                case CapabilityCatalog.GENERATION_DETAIL -> generationDetail(params, actor);
                case CapabilityCatalog.SCHEDULER_LIST -> schedulers(params, actor);
                case CapabilityCatalog.SCHEDULER_EXECUTION_LIST -> schedulerExecutions(params, actor);
                case CapabilityCatalog.USER_LIST -> users(params);
                case CapabilityCatalog.DEPARTMENT_LIST -> departments(params);
                case CapabilityCatalog.CONFIG_LIST -> configs(params);
                case CapabilityCatalog.CONFIG_DETAIL -> configDetail(params);
                case CapabilityCatalog.DICT_TYPE_LIST -> dictTypes(params);
                case CapabilityCatalog.DICT_ITEM_LIST -> dictItems(params);
                case CapabilityCatalog.PROJECT_MEMBER_LIST -> projectMembers(params);
                case CapabilityCatalog.PROJECT_ROLE_LIST -> projectRoles(params);
                case CapabilityCatalog.OPERATION_LOG_LIST -> operationLogs(params);
                case CapabilityCatalog.LOGIN_LOG_LIST -> loginLogs(params);
                case CapabilityCatalog.SESSION_LIST -> sessions(params);
                case CapabilityCatalog.AI_PROVIDER_STATUS -> aiProviderStatus();
                case CapabilityCatalog.I18N_MESSAGE_LIST -> i18nMessages(params);
                case CapabilityCatalog.I18N_LOCALE_LIST -> i18nLocales();
                case CapabilityCatalog.PROJECT_MENU_LIST -> projectMenus(params);
                default -> throw new PlanRejectedException(3, "不可用的能力：" + capability.code());
            };
        } catch (PlanRejectedException rejected) {
            throw rejected;
        } catch (ApiException rejected) {
            // 资源不存在与不属于当前用户必须采用相同口径，避免凭任务号/项目号探测存在性。
            if (rejected.getStatus() == HttpStatus.FORBIDDEN
                    || rejected.getStatus() == HttpStatus.UNAUTHORIZED
                    || rejected.getStatus() == HttpStatus.NOT_FOUND) {
                throw new PlanRejectedException(3, "无权限操作");
            }
            log.warn("agent capability failed: capability={} status={}", capability.code(), rejected.getStatus());
            return CapabilityResult.failed(capability.code(), title(capability), "该项数据暂时取不到");
        } catch (RuntimeException exception) {
            // 只记能力与异常类型，不记参数值与结果内容（logging.no-sensitive-data 是 MUST）。
            log.warn(
                    "agent capability failed: capability={} error={}",
                    capability.code(),
                    exception.getClass().getSimpleName());
            return CapabilityResult.failed(capability.code(), title(capability), "该项数据暂时取不到");
        }
    }

    /** 平台级项目列表：ProjectService.page 只按 keyword 过滤，可见性由平台权限决定。 */
    private CapabilityResult projects(Map<String, Object> params) {
        String keyword = text(params.get("keyword"));
        long size = number(params.get("pageSize"), 20);
        var page = projectService.page(keyword, 1, size);
        String status = text(params.get("status"));

        List<Map<String, Object>> rows = new ArrayList<>();
        Set<String> sources = new LinkedHashSet<>();
        page.records().forEach(view -> {
            if (status != null && !status.equals(view.status())) {
                return;
            }
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", view.id());
            row.put("projectCode", view.projectCode());
            row.put("projectName", view.projectName());
            row.put("status", view.status());
            // 卡片需要据此判断是否允许进入；ResultProjector 的 outboundFields 不包含它，模型看不到地址。
            row.put("backendUrl", view.backendUrl());
            row.put(CardProjection.SOURCE_PROJECT_ID, view.id());
            rows.add(row);
            sources.add(view.id());
        });
        return CapabilityResult.ok(CapabilityCatalog.PROJECT_LIST, "项目", rows, List.copyOf(sources));
    }

    private CapabilityResult projectDetail(Map<String, Object> params) {
        String projectId = text(params.get("projectId"));
        if (projectId == null) throw new PlanRejectedException(6, "请选择项目");
        var project = projectService.project(projectId);
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("id", project.id());
        row.put("projectCode", project.projectCode());
        row.put("projectName", project.projectName());
        if (project.description() != null) row.put("description", project.description());
        row.put("status", project.status());
        if (project.packageName() != null) row.put("packageName", project.packageName());
        if (project.defaultBranch() != null) row.put("defaultBranch", project.defaultBranch());
        row.put(CardProjection.SOURCE_PROJECT_ID, project.id());
        return CapabilityResult.ok(CapabilityCatalog.PROJECT_DETAIL, "项目详情", List.of(row), List.of(project.id()));
    }

    /** 我发起的生成任务：必须传 ownerUserId，否则会看到别人的任务。 */
    private CapabilityResult generations(Map<String, Object> params, KaiwuContext actor) {
        String projectId = text(params.get("projectId"));
        String status = text(params.get("status"));
        long limit = number(params.get("pageSize"), 20);

        List<Map<String, Object>> rows = new ArrayList<>();
        Set<String> sources = new LinkedHashSet<>();
        for (var view : generationService.list(actor.userId(), projectId)) {
            if (status != null && !status.equals(view.status())) {
                continue;
            }
            if (rows.size() >= limit) {
                break;
            }
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("taskNo", view.taskNo());
            row.put("projectCode", view.projectCode());
            row.put("projectName", view.projectName());
            row.put("status", view.status());
            row.put("generationMode", view.generationMode());
            row.put(CardProjection.SOURCE_PROJECT_ID, view.projectId());
            rows.add(row);
            if (view.projectId() != null) {
                sources.add(view.projectId());
            }
        }
        return CapabilityResult.ok(CapabilityCatalog.GENERATION_LIST, "生成任务", rows, List.copyOf(sources));
    }

    private CapabilityResult generationDetail(Map<String, Object> params, KaiwuContext actor) {
        String taskNo = text(params.get("taskNo"));
        if (taskNo == null) throw new PlanRejectedException(6, "请选择生成任务");
        // 与 ProjectGenerationController.get 一致，Service 必须收到当前发起人的 userId。
        var view = generationService.get(taskNo, actor.userId());
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("taskNo", view.taskNo());
        row.put("projectCode", view.projectCode());
        row.put("projectName", view.projectName());
        row.put("generationMode", view.generationMode());
        row.put("status", view.status());
        row.put("templateVersion", view.templateVersion());
        if (view.startedAt() != null) row.put("startedAt", view.startedAt().toString());
        if (view.completedAt() != null)
            row.put("completedAt", view.completedAt().toString());
        row.put(CardProjection.SOURCE_PROJECT_ID, view.projectId());
        return CapabilityResult.ok(
                CapabilityCatalog.GENERATION_DETAIL, "生成任务详情", List.of(row), List.of(view.projectId()));
    }

    /** 定时任务：整个 Context 交给 Service，由它做成员关系收窄。 */
    private CapabilityResult schedulers(Map<String, Object> params, KaiwuContext actor) {
        String projectId = text(params.get("projectId"));
        long size = number(params.get("pageSize"), 20);
        Boolean enabled = params.get("enabled") instanceof Boolean flag ? flag : null;

        var page = schedulerService.jobs(projectId, 1, size, actor);
        List<Map<String, Object>> rows = new ArrayList<>();
        Set<String> sources = new LinkedHashSet<>();
        page.records().forEach(view -> {
            if (enabled != null && enabled != view.enabled()) {
                return;
            }
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", view.id());
            row.put("jobName", view.jobName());
            row.put("projectName", view.projectName());
            row.put("taskType", view.taskType());
            row.put("enabled", view.enabled());
            row.put("lastRunTime", view.lastRunTime());
            row.put(CardProjection.SOURCE_PROJECT_ID, view.projectId());
            rows.add(row);
            if (view.projectId() != null) {
                sources.add(view.projectId());
            }
        });
        return CapabilityResult.ok(CapabilityCatalog.SCHEDULER_LIST, "定时任务", rows, List.copyOf(sources));
    }

    private CapabilityResult schedulerExecutions(Map<String, Object> params, KaiwuContext actor) {
        String projectId = text(params.get("projectId"));
        String jobId = text(params.get("jobId"));
        long size = number(params.get("pageSize"), 20);
        var page = schedulerService.executions(projectId, jobId, 1, size, actor);
        List<Map<String, Object>> rows = new ArrayList<>();
        Set<String> sources = new LinkedHashSet<>();
        page.records().forEach(view -> {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", view.id());
            row.put("jobId", view.jobId());
            row.put("jobName", view.jobName());
            row.put("projectName", view.projectName());
            row.put("status", view.status());
            row.put("scheduledAt", view.scheduledAt());
            row.put("completedAt", view.completedAt());
            row.put(CardProjection.SOURCE_PROJECT_ID, view.projectId());
            rows.add(row);
            if (view.projectId() != null) sources.add(view.projectId());
        });
        return CapabilityResult.ok(CapabilityCatalog.SCHEDULER_EXECUTION_LIST, "任务执行记录", rows, List.copyOf(sources));
    }

    private CapabilityResult users(Map<String, Object> params) {
        String keyword = text(params.get("keyword"));
        long size = number(params.get("pageSize"), 20);
        var page = userService.page(keyword, 1, size);
        List<Map<String, Object>> rows = new ArrayList<>();
        page.records().forEach(view -> {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", view.id());
            row.put("username", view.username());
            row.put("displayName", view.displayName());
            row.put("status", view.status());
            rows.add(row);
        });
        return CapabilityResult.ok(CapabilityCatalog.USER_LIST, "平台用户", rows, List.of());
    }

    private CapabilityResult departments(Map<String, Object> params) {
        long page = number(params.get("page"), 1);
        long size = number(params.get("pageSize"), 20);
        var pending = new ArrayDeque<DepartmentView>(orgService.departments());
        List<Map<String, Object>> rows = new ArrayList<>();
        long seen = 0;
        long offset = (page - 1) * size;
        while (!pending.isEmpty() && rows.size() < size) {
            var department = pending.removeFirst();
            if (department.children() != null) pending.addAll(department.children());
            if (seen++ < offset) continue;
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", department.id());
            row.put("parentId", department.parentId());
            row.put("name", department.name());
            row.put("code", department.code());
            row.put("status", department.status());
            rows.add(row);
        }
        if (!rows.isEmpty()) rows.getLast().put("moreAvailable", !pending.isEmpty());
        return CapabilityResult.ok(CapabilityCatalog.DEPARTMENT_LIST, "部门", rows, List.of());
    }

    private CapabilityResult configs(Map<String, Object> params) {
        // 固定平台作用域；项目配置若加入能力，须独立核对项目成员身份。
        var all = metadataService.configs(MetadataService.GLOBAL_SCOPE).stream()
                .filter(view -> !view.secret())
                .map(view -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("id", view.id());
                    row.put("configKey", view.configKey());
                    row.put("valueType", view.valueType());
                    row.put("status", view.status());
                    row.put("description", view.description());
                    return row;
                })
                .toList();
        return CapabilityResult.ok(CapabilityCatalog.CONFIG_LIST, "平台参数配置", paged(all, params), List.of());
    }

    private CapabilityResult configDetail(Map<String, Object> params) {
        String id = text(params.get("configId"));
        if (id == null) throw new PlanRejectedException(3, "无权限操作");
        // 与列表共用固定平台作用域和安全投影；即使知道敏感配置 ID 也不暴露其存在。
        var row = metadataService.configs(MetadataService.GLOBAL_SCOPE).stream()
                .filter(view -> id.equals(view.id()) && !view.secret())
                .findFirst()
                .orElseThrow(() -> new PlanRejectedException(3, "无权限操作"));
        Map<String, Object> safe = new LinkedHashMap<>();
        safe.put("id", row.id());
        safe.put("configKey", row.configKey());
        safe.put("valueType", row.valueType());
        safe.put("status", row.status());
        safe.put("description", row.description());
        return CapabilityResult.ok(CapabilityCatalog.CONFIG_DETAIL, "平台参数配置详情", List.of(safe), List.of());
    }

    private CapabilityResult dictTypes(Map<String, Object> params) {
        var all = metadataService.dictTypes(MetadataService.GLOBAL_SCOPE).stream()
                .map(view -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("id", view.id());
                    row.put("dictCode", view.dictCode());
                    row.put("dictName", view.dictName());
                    row.put("status", view.status());
                    row.put("description", view.description());
                    return row;
                })
                .toList();
        return CapabilityResult.ok(CapabilityCatalog.DICT_TYPE_LIST, "平台字典", paged(all, params), List.of());
    }

    private CapabilityResult dictItems(Map<String, Object> params) {
        String typeId = text(params.get("typeId"));
        if (typeId == null) throw new PlanRejectedException(6, "请选择字典");
        var all = metadataService.dictItems(MetadataService.GLOBAL_SCOPE, typeId).stream()
                .map(view -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("id", view.id());
                    row.put("itemLabel", view.itemLabel());
                    row.put("itemValue", view.itemValue());
                    row.put("status", view.status());
                    return row;
                })
                .toList();
        return CapabilityResult.ok(CapabilityCatalog.DICT_ITEM_LIST, "平台字典项", paged(all, params), List.of());
    }

    private CapabilityResult projectMembers(Map<String, Object> params) {
        String projectId = requiredProjectId(params);
        var all = projectService.members(projectId).stream()
                .map(view -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("userId", view.userId());
                    row.put("username", view.username());
                    row.put("displayName", view.displayName());
                    row.put("status", view.status());
                    row.put("roleIds", view.roleIds());
                    row.put(CardProjection.SOURCE_PROJECT_ID, projectId);
                    return row;
                })
                .toList();
        return CapabilityResult.ok(
                CapabilityCatalog.PROJECT_MEMBER_LIST, "项目成员", paged(all, params), List.of(projectId));
    }

    private CapabilityResult projectRoles(Map<String, Object> params) {
        String projectId = requiredProjectId(params);
        var all = projectService.roles(projectId).stream()
                .map(view -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("id", view.id());
                    row.put("roleCode", view.roleCode());
                    row.put("roleName", view.roleName());
                    row.put("status", view.status());
                    row.put("builtIn", view.builtIn());
                    row.put(CardProjection.SOURCE_PROJECT_ID, projectId);
                    return row;
                })
                .toList();
        return CapabilityResult.ok(CapabilityCatalog.PROJECT_ROLE_LIST, "项目角色", paged(all, params), List.of(projectId));
    }

    private CapabilityResult projectMenus(Map<String, Object> params) {
        String projectId = requiredProjectId(params);
        var pending = new ArrayDeque<ProjectMenuView>(projectService.menus(projectId));
        List<Map<String, Object>> rows = new ArrayList<>();
        long page = number(params.get("page"), 1);
        long size = number(params.get("pageSize"), 20);
        long offset = (page - 1) * size;
        long seen = 0;
        while (!pending.isEmpty() && rows.size() < size) {
            var menu = pending.removeFirst();
            if (menu.children() != null) pending.addAll(menu.children());
            if (seen++ < offset) continue;
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", menu.id());
            row.put("parentId", menu.parentId());
            row.put("menuName", menu.menuName());
            row.put("menuType", menu.menuType());
            row.put("visible", menu.visible());
            row.put("status", menu.status());
            row.put(CardProjection.SOURCE_PROJECT_ID, projectId);
            rows.add(row);
        }
        if (!rows.isEmpty()) rows.getLast().put("moreAvailable", !pending.isEmpty());
        return CapabilityResult.ok(CapabilityCatalog.PROJECT_MENU_LIST, "项目菜单", rows, List.of(projectId));
    }

    private CapabilityResult operationLogs(Map<String, Object> params) {
        long page = number(params.get("page"), 1);
        long size = number(params.get("pageSize"), 20);
        var result = logCenterService.operations(text(params.get("username")), text(params.get("module")), page, size);
        var rows = result.records().stream()
                .map(view -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("id", view.id());
                    row.put("username", view.username());
                    row.put("module", view.module());
                    row.put("operation", view.operation());
                    row.put("responseStatus", view.responseStatus());
                    if (view.createdAt() != null)
                        row.put("createdAt", view.createdAt().toString());
                    return row;
                })
                .toList();
        return CapabilityResult.ok(CapabilityCatalog.OPERATION_LOG_LIST, "操作审计", withMore(rows, result), List.of());
    }

    private CapabilityResult loginLogs(Map<String, Object> params) {
        long page = number(params.get("page"), 1);
        long size = number(params.get("pageSize"), 20);
        var result = logCenterService.logins(text(params.get("username")), text(params.get("status")), page, size);
        var rows = result.records().stream()
                .map(view -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("id", view.id());
                    row.put("username", view.username());
                    row.put("status", view.status());
                    if (view.createdAt() != null)
                        row.put("createdAt", view.createdAt().toString());
                    return row;
                })
                .toList();
        return CapabilityResult.ok(CapabilityCatalog.LOGIN_LOG_LIST, "登录审计", withMore(rows, result), List.of());
    }

    private CapabilityResult sessions(Map<String, Object> params) {
        long page = number(params.get("page"), 1);
        long size = number(params.get("pageSize"), 20);
        var result = logCenterService.sessions(text(params.get("username")), text(params.get("status")), page, size);
        var rows = result.records().stream()
                .map(view -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("username", view.username());
                    row.put("status", view.status());
                    if (view.createdAt() != null)
                        row.put("createdAt", view.createdAt().toString());
                    if (view.lastSeenAt() != null)
                        row.put("lastSeenAt", view.lastSeenAt().toString());
                    if (view.expiresAt() != null)
                        row.put("expiresAt", view.expiresAt().toString());
                    return row;
                })
                .toList();
        return CapabilityResult.ok(CapabilityCatalog.SESSION_LIST, "平台会话", withMore(rows, result), List.of());
    }

    private CapabilityResult aiProviderStatus() {
        var view = aiProviderService.current();
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("providerName", view.providerName());
        row.put("model", view.model());
        row.put("apiKeyConfigured", view.apiKeyConfigured());
        row.put("lastTestStatus", view.lastTestStatus());
        if (view.lastTestAt() != null) row.put("lastTestAt", view.lastTestAt().toString());
        return CapabilityResult.ok(CapabilityCatalog.AI_PROVIDER_STATUS, "AI 服务状态", List.of(row), List.of());
    }

    private CapabilityResult i18nMessages(Map<String, Object> params) {
        String keyword = text(params.get("keyword"));
        var all = i18nService.messages().stream()
                .filter(view -> keyword == null || view.messageKey().contains(keyword))
                .map(view -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("id", view.id());
                    row.put("messageKey", view.messageKey());
                    row.put("moduleCode", view.moduleCode());
                    row.put("publicVisible", view.publicVisible());
                    row.put("requiredResource", view.requiredResource());
                    row.put("status", view.status());
                    return row;
                })
                .toList();
        return CapabilityResult.ok(CapabilityCatalog.I18N_MESSAGE_LIST, "国际化资源", paged(all, params), List.of());
    }

    private CapabilityResult i18nLocales() {
        var rows = i18nService.locales("zh-CN").stream()
                .map(view -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("locale", view.locale());
                    row.put("label", view.label());
                    row.put("selectableConfigured", view.selectableConfigured());
                    row.put("selectable", view.selectable());
                    row.put("missingRequiredResources", view.missingRequiredResources());
                    row.put("missingMenus", view.missingMenus());
                    row.put("missingDictionaryItems", view.missingDictionaryItems());
                    return row;
                })
                .toList();
        return CapabilityResult.ok(CapabilityCatalog.I18N_LOCALE_LIST, "语言覆盖", rows, List.of());
    }

    private static List<Map<String, Object>> withMore(List<Map<String, Object>> rows, PageResult<?> page) {
        if (!rows.isEmpty()) rows.getLast().put("moreAvailable", page.current() * page.size() < page.total());
        return rows;
    }

    private static String requiredProjectId(Map<String, Object> params) {
        String projectId = text(params.get("projectId"));
        if (projectId == null) throw new PlanRejectedException(6, "请选择项目");
        return projectId;
    }

    private static List<Map<String, Object>> paged(List<Map<String, Object>> all, Map<String, Object> params) {
        long page = number(params.get("page"), 1);
        long size = number(params.get("pageSize"), 20);
        long from = (page - 1) * size;
        if (from >= all.size()) return List.of();
        int start = (int) from;
        int end = (int) Math.min(all.size(), from + size);
        List<Map<String, Object>> rows = new ArrayList<>(all.subList(start, end));
        rows.getLast().put("moreAvailable", end < all.size());
        return rows;
    }

    private static String title(Capability capability) {
        return switch (capability.code()) {
            case CapabilityCatalog.PROJECT_LIST -> "项目";
            case CapabilityCatalog.PROJECT_DETAIL -> "项目详情";
            case CapabilityCatalog.GENERATION_LIST -> "生成任务";
            case CapabilityCatalog.GENERATION_DETAIL -> "生成任务详情";
            case CapabilityCatalog.SCHEDULER_LIST -> "定时任务";
            case CapabilityCatalog.SCHEDULER_EXECUTION_LIST -> "任务执行记录";
            case CapabilityCatalog.USER_LIST -> "平台用户";
            case CapabilityCatalog.DEPARTMENT_LIST -> "部门";
            case CapabilityCatalog.CONFIG_LIST -> "平台参数配置";
            case CapabilityCatalog.CONFIG_DETAIL -> "平台参数配置详情";
            case CapabilityCatalog.DICT_TYPE_LIST -> "平台字典";
            case CapabilityCatalog.DICT_ITEM_LIST -> "平台字典项";
            case CapabilityCatalog.PROJECT_MEMBER_LIST -> "项目成员";
            case CapabilityCatalog.PROJECT_ROLE_LIST -> "项目角色";
            case CapabilityCatalog.OPERATION_LOG_LIST -> "操作审计";
            case CapabilityCatalog.LOGIN_LOG_LIST -> "登录审计";
            case CapabilityCatalog.SESSION_LIST -> "平台会话";
            case CapabilityCatalog.AI_PROVIDER_STATUS -> "AI 服务状态";
            case CapabilityCatalog.I18N_MESSAGE_LIST -> "国际化资源";
            case CapabilityCatalog.I18N_LOCALE_LIST -> "语言覆盖";
            case CapabilityCatalog.PROJECT_MENU_LIST -> "项目菜单";
            default -> capability.code();
        };
    }

    private static String text(Object value) {
        if (value == null) {
            return null;
        }
        String result = String.valueOf(value).trim();
        return result.isEmpty() ? null : result;
    }

    private static long number(Object value, long fallback) {
        return value instanceof Number n ? n.longValue() : fallback;
    }
}
