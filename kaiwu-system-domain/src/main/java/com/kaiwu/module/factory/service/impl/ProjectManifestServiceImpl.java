package com.kaiwu.module.factory.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.I18nService;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.factory.convert.ProjectManifestParser;
import com.kaiwu.module.factory.dto.ProjectManifestRequest;
import com.kaiwu.module.factory.entity.ProjectHandoverRow;
import com.kaiwu.module.factory.model.ProjectManifest;
import com.kaiwu.module.factory.service.ProjectManifestService;
import com.kaiwu.module.factory.vo.ProjectHandoverView;
import com.kaiwu.module.factory.vo.ProjectManifestPlanView;
import com.kaiwu.module.i18n.dto.I18nMessageSaveRequest;
import com.kaiwu.module.i18n.vo.I18nMessageView;
import com.kaiwu.module.metadata.dto.ConfigSaveRequest;
import com.kaiwu.module.metadata.dto.DictItemSaveRequest;
import com.kaiwu.module.metadata.dto.DictTypeSaveRequest;
import com.kaiwu.module.metadata.vo.ConfigView;
import com.kaiwu.module.metadata.vo.DictItemView;
import com.kaiwu.module.metadata.vo.DictTypeView;
import com.kaiwu.module.operation.dto.request.SchedulerJobSaveRequest;
import com.kaiwu.module.operation.service.ProjectSchedulerService;
import com.kaiwu.module.operation.vo.SchedulerJobView;
import com.kaiwu.module.project.dto.ProjectMenuRequest;
import com.kaiwu.module.project.dto.ProjectRoleCreateRequest;
import com.kaiwu.module.project.dto.ProjectRoleDataScopeRequest;
import com.kaiwu.module.project.model.ProjectAccessPermissions;
import com.kaiwu.module.project.service.ProjectAccessGuard;
import com.kaiwu.module.project.service.ProjectDataScopeService;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.vo.ProjectDataResourceView;
import com.kaiwu.module.project.vo.ProjectMenuView;
import com.kaiwu.module.project.vo.ProjectRoleDataScopeView;
import com.kaiwu.module.project.vo.ProjectRoleView;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.ProjectGenerationProjectPort;
import com.kaiwu.starter.KaiwuContext;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.function.Consumer;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;

/**
 * 平台资源清单同步实现（ADR 0036）。
 *
 * <p>所有写操作都经由现有的字典、配置、国际化、菜单与角色服务完成，审计、校验与缓存刷新
 * 与网页上的操作一致。计划与执行使用同一套差异计算，执行前重新计算并比对哈希，
 * 平台在计划之后被改动时拒绝执行。</p>
 */
@Service
public class ProjectManifestServiceImpl implements ProjectManifestService {

    /** 执行同步需要的平台权限；计划阶段只报告缺失，不拒绝。 */
    static final List<String> REQUIRED_PERMISSIONS =
            List.of("system:dict:save", "system:config:save", "system:project:menu");

    private final ProjectManifestParser parser;
    private final ProjectGenerationProjectPort projects;
    private final ProjectService projectService;
    private final MetadataService metadata;
    private final I18nService i18n;
    private final AuditPort audit;
    private final ObjectMapper objectMapper;
    private final ProjectAccessGuard accessGuard;
    private final ProjectHandoverRecorder recorder;
    private final ProjectSchedulerService scheduler;
    private final ProjectDataScopeService dataScopes;

    /** 注入清单解析器、被复用的平台服务，以及移交记录与项目内授权守卫。 */
    public ProjectManifestServiceImpl(
            ProjectManifestParser parser,
            ProjectGenerationProjectPort projects,
            ProjectService projectService,
            MetadataService metadata,
            I18nService i18n,
            AuditPort audit,
            ObjectMapper objectMapper,
            ProjectAccessGuard accessGuard,
            ProjectHandoverRecorder recorder,
            ProjectSchedulerService scheduler,
            ProjectDataScopeService dataScopes) {
        this.parser = parser;
        this.projects = projects;
        this.projectService = projectService;
        this.metadata = metadata;
        this.i18n = i18n;
        this.audit = audit;
        this.objectMapper = objectMapper;
        this.accessGuard = accessGuard;
        this.recorder = recorder;
        this.scheduler = scheduler;
        this.dataScopes = dataScopes;
    }

    /** 只读计划；调用者必须是该项目的有效项目管理员。 */
    @Override
    public ProjectManifestPlanView plan(String projectId, ProjectManifestRequest request, KaiwuContext actor) {
        ProjectView project = projects.requireProjectAdmin(projectId, actor.userId());
        ProjectManifest manifest = parser.parse(request.files());
        Optional<Set<String>> baseline = recorder.baselineKeys(project.id());
        Draft draft = draft(project, manifest, actor, null, baseline);
        ProjectManifestPlanView.AlreadyApplied applied = recorder.findAppliedByDigest(
                        project.id(), request.packageDigest())
                .map(row -> new ProjectManifestPlanView.AlreadyApplied(
                        row.id(), String.valueOf(row.createdAt()), row.operatorId()))
                .orElse(null);
        return view(draft, missingPermissions(actor, manifest), baseline.isPresent(), applied);
    }

    /**
     * 执行同步。
     *
     * <p>权限不全时整体拒绝，不做部分同步；哈希不一致说明平台在计划之后被改动，要求重新计划。
     * 授权类变更只在勾选导入授权时执行，删除类变更只执行勾选的条目；执行失败时业务写入整体回滚，
     * 失败原因另行记录。成功时在同一事务里写移交记录。</p>
     */
    @Override
    @Transactional
    public ProjectManifestPlanView apply(
            String projectId, ProjectManifestRequest request, KaiwuContext actor, RequestMetadata requestMetadata) {
        ProjectView project = projects.requireProjectAdmin(projectId, actor.userId());
        ProjectManifest manifest = parser.parse(request.files());
        List<String> missing = missingPermissions(actor, manifest);
        if (!missing.isEmpty()) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN, "同步清单缺少平台权限：" + String.join("、", missing), "api.common.forbidden");
        }
        Optional<Set<String>> baseline = recorder.baselineKeys(project.id());
        Draft draft = draft(project, manifest, actor, requestMetadata, baseline);
        if (request.planHash() == null || !request.planHash().equals(draft.hash())) {
            throw new ApiException(HttpStatus.CONFLICT, "平台状态在计划之后发生了变化，请重新查看计划后再执行", "api.common.conflict");
        }
        Set<String> deleteKeys = new LinkedHashSet<>(request.deleteKeys());
        requireSelectionPermissions(project.id(), draft, request.applyAccess(), deleteKeys, actor);
        try {
            Map<String, String> created = new HashMap<>();
            int[] counts = execute(draft, request.applyAccess(), deleteKeys, created);
            audit.recordOperation(
                    actor,
                    "SYNC_PROJECT_MANIFEST",
                    "/api/projects/" + projectId + "/manifest/apply",
                    "commit=" + Objects.toString(request.gitCommit(), "") + ",plan=" + draft.hash() + ",changes="
                            + counts[0] + ",deletes=" + counts[1] + ",access=" + request.applyAccess(),
                    requestMetadata);
            recorder.recordSuccess(
                    row(project.id(), "SUCCESS", request, draft.hash(), actor, counts, null),
                    draft.changes(),
                    packageKeys(manifest));
        } catch (RuntimeException exception) {
            recorder.recordFailure(
                    row(project.id(), "FAILED", request, draft.hash(), actor, new int[] {0, 0}, reason(exception)),
                    draft.changes());
            throw exception;
        }
        return view(draft, List.of(), baseline.isPresent(), null);
    }

    /** 项目的移交记录，最新在前；调用者必须是该项目的有效项目管理员。 */
    @Override
    public List<ProjectHandoverView> handovers(String projectId, KaiwuContext actor) {
        ProjectView project = projects.requireProjectAdmin(projectId, actor.userId());
        return recorder.list(project.id());
    }

    /** 一条移交记录及其条目明细；记录不属于该项目时按不存在处理。 */
    @Override
    public ProjectHandoverView handover(String projectId, String handoverId, KaiwuContext actor) {
        ProjectView project = projects.requireProjectAdmin(projectId, actor.userId());
        return recorder.detail(project.id(), handoverId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "移交记录不存在", "api.common.notFound"));
    }

    /**
     * 按勾选执行操作：普通变更总是执行，授权变更需勾选导入授权，删除变更只执行勾选项；
     * 删除按资源依赖顺序执行（字典项、配置、角色、菜单由深到浅、字典类型）。
     *
     * @return {新增与更新条数, 删除条数}
     */
    private static int[] execute(
            Draft draft, boolean applyAccess, Set<String> deleteKeys, Map<String, String> created) {
        draft.operations().stream()
                .filter(operation ->
                        "NORMAL".equals(operation.category()) || ("ACCESS".equals(operation.category()) && applyAccess))
                .forEach(operation -> operation.run().accept(created));
        draft.operations().stream()
                .filter(operation -> "DELETE".equals(operation.category()) && deleteKeys.contains(operation.key()))
                .sorted(Comparator.comparingInt(Operation::order))
                .forEach(operation -> operation.run().accept(created));
        long changed = draft.changes().stream()
                .filter(change -> "CREATE".equals(change.action()) || "UPDATE".equals(change.action()))
                .filter(change -> "NORMAL".equals(change.category()) || applyAccess)
                .count();
        return new int[] {(int) changed, deleteKeys.size()};
    }

    /** 勾选的删除项必须来自计划；导入授权与删除要求项目内相应权限。 */
    private void requireSelectionPermissions(
            String projectId, Draft draft, boolean applyAccess, Set<String> deleteKeys, KaiwuContext actor) {
        Set<String> deletable = new HashSet<>();
        draft.operations().stream()
                .filter(operation -> "DELETE".equals(operation.category()))
                .forEach(operation -> deletable.add(operation.key()));
        List<String> unknown = deleteKeys.stream()
                .filter(key -> !deletable.contains(key))
                .sorted()
                .toList();
        if (!unknown.isEmpty()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST, "这些删除项不在计划里：" + String.join("、", unknown), "api.common.badRequest");
        }
        if (applyAccess) {
            accessGuard.require(projectId, actor, ProjectAccessPermissions.ROLE_SAVE);
            accessGuard.require(projectId, actor, ProjectAccessPermissions.ROLE_GRANT);
        }
        List<String> deleteMissing = new ArrayList<>();
        for (String key : deleteKeys) {
            String resource = key.substring(0, key.indexOf('|'));
            switch (resource) {
                case "DICT", "DICT_ITEM" -> addMissing(deleteMissing, actor, "system:dict:delete");
                case "CONFIG" -> addMissing(deleteMissing, actor, "system:config:delete");
                case "JOB" -> addMissing(deleteMissing, actor, "system:scheduler:save");
                case "ROLE" -> accessGuard.require(projectId, actor, ProjectAccessPermissions.ROLE_DELETE);
                default -> {
                    // 菜单删除沿用 system:project:menu，已在执行前整体校验。
                }
            }
        }
        if (!deleteMissing.isEmpty()) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "删除缺少平台权限：" + String.join("、", new TreeSet<>(deleteMissing)),
                    "api.common.forbidden");
        }
    }

    /** 调用者缺少权限码时记入缺失列表。 */
    private static void addMissing(List<String> missing, KaiwuContext actor, String code) {
        if (!actor.permissions().contains(code)) {
            missing.add(code);
        }
    }

    /** 构造移交记录摘要；ID 与创建时间由记录服务生成。 */
    private static ProjectHandoverRow row(
            String projectId,
            String status,
            ProjectManifestRequest request,
            String planHash,
            KaiwuContext actor,
            int[] counts,
            String failureReason) {
        return new ProjectHandoverRow(
                null,
                projectId,
                status,
                request.packageDigest(),
                request.sourceHost(),
                request.sourceExportedBy(),
                request.sourceExportedAt(),
                planHash,
                request.gitCommit(),
                request.applyAccess(),
                counts[0],
                counts[1],
                failureReason,
                actor.userId(),
                LocalDateTime.now());
    }

    /** 失败原因：业务异常取其消息，其余取异常类型，避免把内部细节写进记录。 */
    private static String reason(RuntimeException exception) {
        if (exception instanceof ApiException api && api.getMessage() != null) {
            return api.getMessage();
        }
        return exception.getClass().getSimpleName();
    }

    /** 计算差异与待执行操作；计划阶段 metadata 为空，操作不会被执行。 */
    private Draft draft(
            ProjectView project,
            ProjectManifest manifest,
            KaiwuContext actor,
            RequestMetadata requestMetadata,
            Optional<Set<String>> baseline) {
        Draft draft = new Draft(
                project.id(),
                baseline.orElse(Set.of()),
                new ArrayList<>(),
                new ArrayList<>(),
                new ArrayList<>(),
                new HashSet<>());
        baseline.ifPresent(keys -> draft.observe("BASELINE|" + digestOf(new TreeSet<>(keys))));
        // ADR 0037：项目文案落在项目作用域，key 不需要项目前缀。
        String prefix = "";
        // 国际化资源先于字典与菜单计划：同一个 key 在包里显式给出时，以 i18n.yml 为准。
        planMessages(project.id(), manifest.messages(), draft, actor, requestMetadata);
        planDicts(project.id(), prefix, manifest.dicts(), draft, actor, requestMetadata);
        planConfigs(project.id(), manifest.configs(), draft, actor, requestMetadata);
        planDataResources(project.id(), manifest.dataResources(), draft);
        planMenus(project.id(), prefix, manifest.menus(), draft, actor, requestMetadata);
        planRoles(project.id(), manifest, draft, actor, requestMetadata);
        planJobs(project.id(), manifest.jobs(), draft, actor, requestMetadata);
        driftMessages(project.id(), manifest.messages(), draft, actor, requestMetadata);
        return draft;
    }

    /** 字典类型与字典项的差异。 */
    private void planDicts(
            String projectId,
            String prefix,
            List<ProjectManifest.DictType> dicts,
            Draft draft,
            KaiwuContext actor,
            RequestMetadata requestMetadata) {
        Map<String, DictTypeView> existing = new HashMap<>();
        metadata.dictTypes(projectId).stream()
                .filter(type -> projectId.equals(type.scopeId()))
                .forEach(type -> existing.put(type.dictCode(), type));
        Set<String> declared = new HashSet<>();
        for (ProjectManifest.DictType dict : dicts) {
            declared.add(dict.dictCode());
            String nameKey = referencedI18nKey(
                    prefix + "dictType." + dict.dictCode(), dict.name(), draft, actor, requestMetadata);
            DictTypeView current = existing.get(dict.dictCode());
            String typeRef = "dict:" + dict.dictCode();
            if (current == null) {
                draft.change(
                        "DICT",
                        dict.dictCode(),
                        "CREATE",
                        "新增字典类型「" + dict.name().defaultText() + "」");
                draft.operation(created -> created.put(
                        typeRef,
                        metadata.saveDictType(
                                        projectId,
                                        new DictTypeSaveRequest(
                                                null,
                                                dict.dictCode(),
                                                dict.name().defaultText(),
                                                nameKey,
                                                false,
                                                "ENABLED",
                                                dict.description()),
                                        actor,
                                        requestMetadata)
                                .id()));
            } else {
                draft.observe("DICT|" + current.id() + "|" + current.dictName() + "|" + current.dictNameKey() + "|"
                        + current.description() + "|" + current.inheritGlobal() + "|" + current.status());
                draft.operation(created -> created.put(typeRef, current.id()));
                if ((nameKey == null
                                && !Objects.equals(
                                        current.dictName(), dict.name().defaultText()))
                        || !Objects.equals(current.dictNameKey(), nameKey)
                        || !Objects.equals(current.description(), dict.description())) {
                    draft.change(
                            "DICT",
                            dict.dictCode(),
                            "UPDATE",
                            "更新名称或说明：" + current.dictName() + " → "
                                    + dict.name().defaultText());
                    draft.operation(created -> metadata.saveDictType(
                            projectId,
                            new DictTypeSaveRequest(
                                    current.id(),
                                    dict.dictCode(),
                                    dict.name().defaultText(),
                                    nameKey,
                                    current.inheritGlobal(),
                                    current.status(),
                                    dict.description()),
                            actor,
                            requestMetadata));
                }
            }
            List<DictItemView> currentItems = current == null ? List.of() : metadata.dictItems(projectId, current.id());
            planDictItems(projectId, prefix, dict, typeRef, current, currentItems, draft, actor, requestMetadata);
        }
        existing.keySet().stream()
                .filter(code -> !declared.contains(code))
                .sorted()
                .forEach(code -> draft.drift(
                        "DICT",
                        code,
                        100,
                        () -> metadata.deleteDictType(
                                projectId, existing.get(code).id(), actor, requestMetadata)));
    }

    /**
     * 字典项的差异；清单负责标签、颜色、排序与默认项，状态保持平台现值。
     *
     * <p>带国际化资源的标签以资源文本为准（平台保存时也会据此回填），因此只比较引用的 key，
     * 不比较标签文本，避免运营改译后计划永远显示"需要更新"。</p>
     */
    private void planDictItems(
            String projectId,
            String prefix,
            ProjectManifest.DictType dict,
            String typeRef,
            DictTypeView currentType,
            List<DictItemView> currentItems,
            Draft draft,
            KaiwuContext actor,
            RequestMetadata requestMetadata) {
        Map<String, DictItemView> byValue = new HashMap<>();
        currentItems.forEach(item -> byValue.put(item.itemValue(), item));
        for (ProjectManifest.DictItem item : dict.items()) {
            String key = dict.dictCode() + ":" + item.value();
            String labelKey = referencedI18nKey(
                    prefix + "dict." + dict.dictCode() + "." + safe(item.value()),
                    item.label(),
                    draft,
                    actor,
                    requestMetadata);
            DictItemView current = byValue.remove(item.value());
            if (current != null) {
                draft.observe("DICT_ITEM|" + current.id() + "|" + current.itemLabel() + "|" + current.labelI18nKey()
                        + "|" + current.color() + "|" + current.sortNo() + "|" + current.defaultItem() + "|"
                        + current.status());
            }
            if (current == null) {
                draft.change("DICT_ITEM", key, "CREATE", "新增字典项「" + item.label().defaultText() + "」");
            } else if ((labelKey == null
                            && !Objects.equals(current.itemLabel(), item.label().defaultText()))
                    || !Objects.equals(current.color(), item.color())
                    || current.sortNo() != item.sort()
                    || current.defaultItem() != item.defaultItem()
                    || !Objects.equals(current.labelI18nKey(), labelKey)) {
                draft.change(
                        "DICT_ITEM",
                        key,
                        "UPDATE",
                        "更新标签、颜色、排序或默认项：" + current.itemLabel() + " → "
                                + item.label().defaultText());
            } else {
                continue;
            }
            String itemId = current == null ? null : current.id();
            String status = current == null ? "ENABLED" : current.status();
            String extraJson = current == null ? null : current.extraJson();
            draft.operation(created -> metadata.saveDictItem(
                    projectId,
                    created.get(typeRef),
                    new DictItemSaveRequest(
                            itemId,
                            item.label().defaultText(),
                            item.value(),
                            item.sort(),
                            item.defaultItem(),
                            item.color(),
                            extraJson,
                            labelKey,
                            status),
                    actor,
                    requestMetadata));
        }
        byValue.keySet().stream()
                .sorted()
                .forEach(value -> draft.drift(
                        "DICT_ITEM",
                        dict.dictCode() + ":" + value,
                        10,
                        () -> metadata.deleteDictItem(
                                projectId, currentType.id(), byValue.get(value).id(), actor, requestMetadata)));
    }

    /** 参数配置的差异；当前值归平台运营，已存在时只更新类型与说明。 */
    private void planConfigs(
            String projectId,
            List<ProjectManifest.Config> configs,
            Draft draft,
            KaiwuContext actor,
            RequestMetadata requestMetadata) {
        Map<String, ConfigView> existing = new HashMap<>();
        metadata.configs(projectId).stream()
                .filter(config -> projectId.equals(config.scopeId()))
                .forEach(config -> existing.put(config.configKey(), config));
        Set<String> declared = new HashSet<>();
        for (ProjectManifest.Config config : configs) {
            declared.add(config.key());
            ConfigView current = existing.get(config.key());
            if (current == null) {
                draft.change(
                        "CONFIG", config.key(), "CREATE", "新增配置，初始值 " + Objects.toString(config.defaultValue(), "（空）"));
                draft.operation(created -> metadata.saveConfig(
                        projectId,
                        new ConfigSaveRequest(
                                null,
                                config.key(),
                                config.defaultValue(),
                                null,
                                config.valueType(),
                                false,
                                "ENABLED",
                                config.description(),
                                0),
                        actor,
                        requestMetadata));
                continue;
            }
            // 当前值归平台运营且执行时原样保留，不计入计划基线；其余字段变化会让计划失效。
            draft.observe("CONFIG|" + current.id() + "|" + current.valueType() + "|" + current.description() + "|"
                    + current.status() + "|" + current.secret());
            if (current.secret()) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST, "平台上的同名配置 " + config.key() + " 是敏感项，清单不能管理", "api.common.badRequest");
            }
            if (!Objects.equals(current.valueType(), config.valueType())
                    || !Objects.equals(current.description(), config.description())) {
                draft.change("CONFIG", config.key(), "UPDATE", "更新类型或说明，保留当前值");
                draft.operation(created -> metadata.saveConfig(
                        projectId,
                        new ConfigSaveRequest(
                                current.id(),
                                current.configKey(),
                                current.configValue(),
                                current.valueI18nKey(),
                                config.valueType(),
                                false,
                                current.status(),
                                config.description(),
                                current.sortNo()),
                        actor,
                        requestMetadata));
            }
        }
        existing.keySet().stream()
                .filter(key -> !declared.contains(key))
                .sorted()
                .forEach(key -> draft.drift(
                        "CONFIG",
                        key,
                        20,
                        () -> metadata.deleteConfig(projectId, existing.get(key).id(), actor, requestMetadata)));
    }

    /**
     * 受控数据资源的差异（ADR 0044）。
     *
     * <p>只涉及资源声明，不产生任何授权变化，所以随计划普通执行而不需要勾选导入授权。清单里消失的资源不会自动下线，
     * 只作为漂移展示，由管理员决定；允许范围被收窄时，计划里写明有多少角色配置会因此按仅本人生效。</p>
     */
    private void planDataResources(String projectId, List<ProjectManifest.DataResource> declared, Draft draft) {
        Map<String, ProjectDataResourceView> existing = new HashMap<>();
        dataScopes.resources(projectId).forEach(resource -> existing.put(resource.code(), resource));
        Set<String> declaredCodes = new HashSet<>();
        for (ProjectManifest.DataResource resource : declared) {
            declaredCodes.add(resource.code());
            ProjectDataResourceView current = existing.get(resource.code());
            String allowed = String.join("、", resource.allowedScopes());
            if (current == null) {
                draft.change(
                        "DATA_SCOPE", resource.code(), "CREATE", "声明受控资源「" + resource.name() + "」，允许范围 " + allowed);
                draft.operation(created ->
                        dataScopes.saveResource(projectId, resource.code(), resource.name(), resource.allowedScopes()));
                continue;
            }
            draft.observe("DATA_SCOPE|" + current.code() + "|" + current.name() + "|"
                    + String.join(",", current.allowedScopes()) + "|" + current.status());
            boolean disabled = "DISABLED".equals(current.status());
            boolean changed = !Objects.equals(current.name(), resource.name())
                    || !Objects.equals(current.allowedScopes(), resource.allowedScopes());
            if (!disabled && !changed) {
                continue;
            }
            long narrowed = Objects.equals(current.allowedScopes(), resource.allowedScopes())
                    ? 0
                    : dataScopes.configsOutside(projectId, resource.code(), resource.allowedScopes());
            String detail = (disabled ? "重新启用并" : "") + "更新为「" + resource.name() + "」，允许范围 " + allowed
                    + (narrowed > 0 ? "；有 " + narrowed + " 个角色配置超出新范围，将按仅本人生效，需管理员重新选择" : "");
            draft.change("DATA_SCOPE", resource.code(), disabled ? "REENABLE" : "UPDATE", detail);
            draft.operation(created ->
                    dataScopes.saveResource(projectId, resource.code(), resource.name(), resource.allowedScopes()));
        }
        existing.keySet().stream()
                .filter(code -> !declaredCodes.contains(code))
                .sorted()
                .forEach(code -> draft.change("DATA_SCOPE", code, "DRIFT", "平台上登记、清单未声明；保持现状，不会自动下线"));
    }

    /** 菜单树的差异；平台新建菜单时会自动授予内置 project-admin，其它角色授权归平台运营。 */
    private void planMenus(
            String projectId,
            String prefix,
            List<ProjectManifest.Menu> menus,
            Draft draft,
            KaiwuContext actor,
            RequestMetadata requestMetadata) {
        if (menus.isEmpty()) {
            return;
        }
        List<ProjectMenuView> flat = new ArrayList<>();
        flatten(projectService.menus(projectId), flat);
        Set<String> matched = new HashSet<>();
        for (int index = 0; index < menus.size(); index++) {
            planMenu(
                    projectId,
                    prefix,
                    menus.get(index),
                    null,
                    "menu#" + index,
                    flat,
                    matched,
                    draft,
                    actor,
                    requestMetadata);
        }
        Map<String, String> identities = new HashMap<>();
        Map<String, Integer> depths = new HashMap<>();
        identify(projectService.menus(projectId), null, 0, identities, depths);
        flat.stream()
                .filter(menu -> !matched.contains(menu.id()))
                .filter(menu -> !isSeededAccessMenu(menu, flat))
                .forEach(menu -> {
                    String identity = identities.getOrDefault(menu.id(), menuIdentity(menu));
                    int depth = depths.getOrDefault(menu.id(), 0);
                    // 子节点先于父节点删除：平台拒绝删除仍有子菜单的节点。
                    draft.drift(
                            "MENU",
                            identity,
                            40 + (50 - depth),
                            () -> projectService.deleteMenu(projectId, menu.id(), actor, requestMetadata));
                });
    }

    /** 递归计算一个菜单节点；父节点可能是平台已有 ID，也可能是本次新增的引用。 */
    private void planMenu(
            String projectId,
            String prefix,
            ProjectManifest.Menu menu,
            ParentRef parent,
            String ref,
            List<ProjectMenuView> flat,
            Set<String> matched,
            Draft draft,
            KaiwuContext actor,
            RequestMetadata requestMetadata) {
        String identity =
                switch (menu.menuType()) {
                    case "BUTTON" -> menu.permission();
                    case "MENU" -> menu.path();
                    default ->
                        (parent == null ? "" : parent.label() + "/")
                                + menu.name().defaultText();
                };
        String nameKey =
                referencedI18nKey(prefix + "menu." + safe(identity), menu.name(), draft, actor, requestMetadata);
        Optional<ProjectMenuView> current = flat.stream()
                .filter(candidate -> !matched.contains(candidate.id()))
                .filter(candidate -> matches(candidate, menu, parent))
                .findFirst();
        if (current.isEmpty()) {
            draft.change(
                    "MENU",
                    identity,
                    "CREATE",
                    "新增 " + menu.menuType() + "「" + menu.name().defaultText() + "」");
            draft.operation(created -> created.put(
                    ref,
                    projectService
                            .createMenu(
                                    projectId,
                                    menuRequest(menu, parent == null ? null : parent.resolve(created), nameKey),
                                    actor,
                                    requestMetadata)
                            .id()));
        } else {
            ProjectMenuView existing = current.get();
            draft.observe("MENU|" + existing.id() + "|" + existing.parentId() + "|" + existing.menuName() + "|"
                    + existing.menuNameKey() + "|" + existing.componentPath() + "|" + existing.icon() + "|"
                    + existing.sortNo());
            matched.add(existing.id());
            draft.operation(created -> created.put(ref, existing.id()));
            String expectedParent = parent == null ? null : parent.existingId();
            boolean parentChanged =
                    parent != null && expectedParent == null || !Objects.equals(existing.parentId(), expectedParent);
            if (parentChanged
                    || (nameKey == null
                            && !Objects.equals(existing.menuName(), menu.name().defaultText()))
                    || !Objects.equals(existing.menuNameKey(), nameKey)
                    || !Objects.equals(existing.componentPath(), menu.component())
                    || !Objects.equals(existing.icon(), menu.icon())
                    || existing.sortNo() != menu.sort()) {
                draft.change("MENU", identity, "UPDATE", "更新名称、组件、图标、排序或父节点");
                draft.operation(created -> projectService.updateMenu(
                        projectId,
                        existing.id(),
                        menuRequest(menu, parent == null ? null : parent.resolve(created), nameKey),
                        actor,
                        requestMetadata));
            }
        }
        ParentRef self = new ParentRef(ref, current.map(ProjectMenuView::id).orElse(null), identity);
        for (int index = 0; index < menu.children().size(); index++) {
            planMenu(
                    projectId,
                    prefix,
                    menu.children().get(index),
                    self,
                    ref + "." + index,
                    flat,
                    matched,
                    draft,
                    actor,
                    requestMetadata);
        }
    }

    /** 为平台已有菜单计算与清单一致的标识（按钮=权限码，页面=路由，目录=父标识/名称）及深度。 */
    private static void identify(
            List<ProjectMenuView> nodes,
            String parentIdentity,
            int depth,
            Map<String, String> identities,
            Map<String, Integer> depths) {
        if (nodes == null) {
            return;
        }
        for (ProjectMenuView node : nodes) {
            String identity =
                    switch (node.menuType()) {
                        case "BUTTON" -> node.permissionCode();
                        case "MENU" -> node.routePath();
                        default -> (parentIdentity == null ? "" : parentIdentity + "/") + node.menuName();
                    };
            identities.put(node.id(), identity);
            depths.put(node.id(), depth);
            identify(node.children(), identity, depth + 1, identities, depths);
        }
    }

    /** 建项目时由平台种入的成员、角色、文件菜单及其按钮，不参与清单比对。 */
    private static boolean isSeededAccessMenu(ProjectMenuView menu, List<ProjectMenuView> all) {
        ProjectMenuView current = menu;
        while (current != null) {
            if ("MENU".equals(current.menuType()) && ProjectManifest.SEEDED_MENU_ROUTES.contains(current.routePath())) {
                return true;
            }
            String parentId = current.parentId();
            current = parentId == null
                    ? null
                    : all.stream()
                            .filter(candidate -> candidate.id().equals(parentId))
                            .findFirst()
                            .orElse(null);
        }
        return false;
    }

    /**
     * 项目国际化资源的差异（ADR 0042）。
     *
     * <p>包里没有 i18n.yml 时不处理。目标已存在而文案不同的按移交包更新；目标多出的资源在最后按基线判断
     * 是否「源环境已删除」，被字典、菜单文本引用的 key 不算多出。</p>
     */
    private void planMessages(
            String projectId,
            List<ProjectManifest.Message> messages,
            Draft draft,
            KaiwuContext actor,
            RequestMetadata md) {
        if (messages.isEmpty()) {
            return;
        }
        Map<String, I18nMessageView> existing = new HashMap<>();
        i18n.projectMessages(projectId).forEach(message -> existing.put(message.messageKey(), message));
        for (ProjectManifest.Message message : messages) {
            draft.referencedKeys().add(message.messageKey());
            String translations = objectMapper.writeValueAsString(new TreeMap<>(message.translations()));
            I18nMessageView current = existing.get(message.messageKey());
            if (current == null) {
                if (draft.reserveI18n(message.messageKey())) {
                    draft.change("I18N", message.messageKey(), "CREATE", "新增国际化资源「" + message.defaultText() + "」");
                    draft.operation(created -> i18n.createProjectMessage(
                            projectId,
                            new I18nMessageSaveRequest(
                                    null,
                                    message.messageKey(),
                                    message.defaultText(),
                                    translations,
                                    "project",
                                    false,
                                    false,
                                    "ENABLED",
                                    message.description(),
                                    null),
                            actor,
                            md));
                }
                continue;
            }
            draft.observe("I18N_MSG|" + current.id() + "|" + current.defaultText() + "|"
                    + translationsOf(current.translationsJson()) + "|" + current.description() + "|"
                    + current.version());
            boolean descriptionChanged =
                    message.description() != null && !message.description().equals(current.description());
            if (!current.defaultText().equals(message.defaultText())
                    || !translationsOf(current.translationsJson()).equals(new TreeMap<>(message.translations()))
                    || descriptionChanged) {
                draft.change(
                        "I18N",
                        message.messageKey(),
                        "UPDATE",
                        "文案变化：" + current.defaultText() + " → " + message.defaultText());
                draft.operation(created -> i18n.saveProjectMessage(
                        projectId,
                        new I18nMessageSaveRequest(
                                current.id(),
                                message.messageKey(),
                                message.defaultText(),
                                translations,
                                current.moduleCode(),
                                current.publicVisible(),
                                current.requiredResource(),
                                current.status(),
                                message.description() != null ? message.description() : current.description(),
                                current.version()),
                        actor,
                        md));
            }
        }
    }

    /** 目标多出的项目国际化资源；被字典、菜单文本或 i18n.yml 引用的不算。 */
    private void driftMessages(
            String projectId,
            List<ProjectManifest.Message> messages,
            Draft draft,
            KaiwuContext actor,
            RequestMetadata md) {
        if (messages.isEmpty()) {
            return;
        }
        i18n.projectMessages(projectId).stream()
                .filter(message -> !draft.referencedKeys().contains(message.messageKey()))
                .sorted(Comparator.comparing(I18nMessageView::messageKey))
                .forEach(message -> draft.drift(
                        "I18N",
                        message.messageKey(),
                        110,
                        () -> i18n.deleteProjectMessage(projectId, message.id(), message.version(), actor, md)));
    }

    /** 译文 JSON 解析为不含 zh-CN 的语言表，便于和移交包比较；格式异常按无译文处理。 */
    private Map<String, String> translationsOf(String json) {
        Map<String, String> result = new TreeMap<>();
        if (json == null || json.isBlank()) {
            return result;
        }
        try {
            Map<?, ?> parsed = objectMapper.readValue(json, Map.class);
            parsed.forEach((locale, value) -> {
                if (!"zh-CN".equals(locale) && value instanceof String text && !text.isBlank()) {
                    result.put(String.valueOf(locale), text);
                }
            });
        } catch (RuntimeException exception) {
            return new TreeMap<>();
        }
        return result;
    }

    /**
     * 定时任务的差异（ADR 0042）。
     *
     * <p>业务键是任务名。新建的任务一律停用，已有任务只更新 cron、时区、类型与参数，不改启用状态；
     * 新建与改任务类型要求目标项目已有在线 Handler，否则整体拒绝并说明原因。包里没有 jobs.yml 时不处理。</p>
     */
    private void planJobs(
            String projectId, List<ProjectManifest.Job> jobs, Draft draft, KaiwuContext actor, RequestMetadata md) {
        if (jobs.isEmpty()) {
            return;
        }
        Map<String, List<SchedulerJobView>> byName = new HashMap<>();
        allJobs(projectId, actor).forEach(job -> byName.computeIfAbsent(job.jobName(), name -> new ArrayList<>())
                .add(job));
        Set<String> declared = new HashSet<>();
        for (ProjectManifest.Job job : jobs) {
            declared.add(job.jobName());
            List<SchedulerJobView> matches = byName.getOrDefault(job.jobName(), List.of());
            if (matches.size() > 1) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "目标项目存在多个同名定时任务：" + job.jobName() + "，请先在目标环境处理",
                        "api.common.badRequest");
            }
            String payload = normalizePayload(job.payload());
            if (matches.isEmpty()) {
                requireHandler(projectId, job);
                draft.change(
                        "JOB", job.jobName(), "CREATE", "新增定时任务（默认停用）：" + job.cronExpression() + " " + job.zoneId());
                draft.operation(created -> scheduler.saveJob(
                        null,
                        new SchedulerJobSaveRequest(
                                projectId,
                                job.jobName(),
                                job.taskType(),
                                job.cronExpression(),
                                job.zoneId(),
                                payload,
                                false),
                        actor,
                        md));
                continue;
            }
            SchedulerJobView current = matches.get(0);
            draft.observe("JOB|" + current.id() + "|" + current.taskType() + "|" + current.cronExpression() + "|"
                    + current.zoneId() + "|" + normalizePayload(current.payload()) + "|" + current.enabled() + "|"
                    + current.configVersion());
            boolean typeChanged = !current.taskType().equals(job.taskType());
            if (typeChanged
                    || !current.cronExpression().equals(job.cronExpression())
                    || !current.zoneId().equals(job.zoneId())
                    || !normalizePayload(current.payload()).equals(payload)) {
                if (typeChanged) {
                    requireHandler(projectId, job);
                }
                draft.change("JOB", job.jobName(), "UPDATE", "更新 cron、时区、任务类型或参数，保留启用状态");
                draft.operation(created -> scheduler.saveJob(
                        current.id(),
                        new SchedulerJobSaveRequest(
                                projectId,
                                job.jobName(),
                                job.taskType(),
                                job.cronExpression(),
                                job.zoneId(),
                                payload,
                                current.enabled()),
                        actor,
                        md));
            }
        }
        byName.values().stream()
                .flatMap(List::stream)
                .filter(job -> !declared.contains(job.jobName()))
                .sorted(Comparator.comparing(SchedulerJobView::jobName))
                .forEach(job -> draft.drift("JOB", job.jobName(), 35, () -> scheduler.deleteJob(job.id(), actor, md)));
    }

    /** 新建任务或改任务类型要求目标项目有在线 Handler，否则明确拒绝，不留半份计划。 */
    private void requireHandler(String projectId, ProjectManifest.Job job) {
        if (!scheduler.handlerActive(projectId, job.taskType())) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "定时任务 " + job.jobName() + " 的 Handler（" + job.taskType() + "）在目标项目未注册或已离线，请先启动目标环境的业务服务",
                    "api.common.badRequest");
        }
    }

    /** 项目全部定时任务，分页读完。 */
    private List<SchedulerJobView> allJobs(String projectId, KaiwuContext actor) {
        List<SchedulerJobView> result = new ArrayList<>();
        long page = 1;
        while (true) {
            PageResult<SchedulerJobView> current = scheduler.jobs(projectId, page, 100, actor);
            result.addAll(current.records());
            if (current.records().isEmpty() || result.size() >= current.total()) {
                return result;
            }
            page++;
        }
    }

    /** 与调度服务一致：空参数按空对象处理。 */
    private static String normalizePayload(String payload) {
        return payload == null || payload.isBlank() ? "{}" : payload.trim();
    }

    /**
     * 角色及授权的差异（ADR 0042）。
     *
     * <p>全部归入「授权」类，勾选导入授权才执行。只追加授权，不撤销目标环境已有的授权；授权引用的菜单必须
     * 在目标项目已有或本次清单会创建，否则整体拒绝。目标多出的自定义角色按基线判断是否「源环境已删除」。</p>
     */
    private void planRoles(
            String projectId, ProjectManifest manifest, Draft draft, KaiwuContext actor, RequestMetadata md) {
        List<ProjectRoleView> existingRoles = projectService.roles(projectId);
        Map<String, ProjectRoleView> byCode = new HashMap<>();
        existingRoles.forEach(role -> byCode.put(role.roleCode(), role));
        Map<String, String> keyByMenuId = new HashMap<>();
        Set<String> knownKeys = new HashSet<>();
        for (Map.Entry<String, String> entry :
                grantKeysOfTree(projectService.menus(projectId)).entrySet()) {
            keyByMenuId.put(entry.getKey(), entry.getValue());
            knownKeys.add(entry.getValue());
        }
        knownKeys.addAll(grantKeysOfManifest(manifest.menus(), ""));
        Map<String, List<String>> allowedByResource = new HashMap<>();
        dataScopes.resources(projectId).stream()
                .filter(resource -> "ENABLED".equals(resource.status()))
                .forEach(resource -> allowedByResource.put(resource.code(), resource.allowedScopes()));
        // 同一次执行会先创建或更新清单里声明的资源，所以角色可以引用它们。
        manifest.dataResources().forEach(resource -> allowedByResource.put(resource.code(), resource.allowedScopes()));
        Set<String> departmentCodes = new HashSet<>();
        manifest.roles().forEach(role -> role.dataScopes().forEach(scope -> departmentCodes.addAll(scope.depts())));
        Map<String, String> departmentIds = dataScopes.departmentIdsByCode(departmentCodes);
        departmentCodes.forEach(code -> draft.observe("DEPT|" + code + "|" + departmentIds.get(code)));
        Set<String> declaredRoles = new HashSet<>();
        for (ProjectManifest.Role role : manifest.roles()) {
            declaredRoles.add(role.roleCode());
            ProjectRoleView current = byCode.get(role.roleCode());
            if (current != null && current.builtIn()) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST, "内置角色不由移交包管理：" + role.roleCode(), "api.common.badRequest");
            }
            List<String> desired = desiredGrants(role);
            List<String> unknown = desired.stream()
                    .filter(key -> !knownKeys.contains(key))
                    .sorted()
                    .toList();
            if (!unknown.isEmpty()) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "角色 " + role.roleCode() + " 的授权引用了不存在的菜单：" + String.join("、", unknown),
                        "api.common.badRequest");
            }
            if (current == null) {
                draft.access("ROLE", role.roleCode(), "CREATE", "新增角色「" + role.roleName() + "」");
                draft.accessOperation(created -> projectService.createRole(
                        projectId,
                        new ProjectRoleCreateRequest(role.roleCode(), role.roleName(), role.description()),
                        actor,
                        md));
            } else {
                draft.observe("ROLE|" + current.id() + "|" + new TreeSet<>(current.menuIds()));
            }
            Set<String> held = new HashSet<>();
            if (current != null) {
                current.menuIds().forEach(id -> {
                    String key = keyByMenuId.get(id);
                    if (key != null) {
                        held.add(key);
                    }
                });
            }
            List<String> toAdd =
                    desired.stream().filter(key -> !held.contains(key)).toList();
            for (String key : toAdd) {
                draft.access("ROLE_GRANT", role.roleCode() + "/" + key, "CREATE", "追加授权 " + key);
            }
            if (!toAdd.isEmpty()) {
                draft.accessOperation(created -> grant(projectId, role.roleCode(), toAdd, actor, md));
            }
            Set<String> desiredSet = new HashSet<>(desired);
            held.stream()
                    .filter(key -> !desiredSet.contains(key))
                    .sorted()
                    .forEach(key -> draft.change("ROLE_GRANT", role.roleCode() + "/" + key, "DRIFT", "目标环境多出的授权；不会撤销"));
            planRoleDataScopes(projectId, role, current, allowedByResource, departmentIds, draft, actor, md);
        }
        existingRoles.stream()
                .filter(role -> !role.builtIn() && !declaredRoles.contains(role.roleCode()))
                .sorted(Comparator.comparing(ProjectRoleView::roleCode))
                .forEach(role -> draft.drift(
                        "ROLE", role.roleCode(), 30, () -> projectService.deleteRole(projectId, role.id(), actor, md)));
    }

    /**
     * 角色数据范围的差异（ADR 0044）。数据范围属于授权：随授权组计划，勾选导入授权才执行，只覆盖清单里出现的资源，
     * 不撤销目标环境多出的配置。
     *
     * <p>引用了目标环境不存在或未启用的资源、不在该资源允许范围内的类型、不存在的部门编码时，整份计划被拒绝并列出全部问题，
     * 与引用不存在的菜单同一处理：不做部分导入，也不静默跳过。</p>
     */
    private void planRoleDataScopes(
            String projectId,
            ProjectManifest.Role role,
            ProjectRoleView current,
            Map<String, List<String>> allowedByResource,
            Map<String, String> departmentIds,
            Draft draft,
            KaiwuContext actor,
            RequestMetadata md) {
        if (role.dataScopes().isEmpty()) {
            return;
        }
        List<String> problems = new ArrayList<>();
        for (ProjectManifest.RoleDataScope item : role.dataScopes()) {
            List<String> allowed = allowedByResource.get(item.resource());
            if (allowed == null) {
                problems.add("资源 " + item.resource() + " 在目标项目不存在或未启用");
            } else if (!allowed.contains(item.scope())) {
                problems.add("资源 " + item.resource() + " 不允许范围 " + item.scope());
            }
            for (String code : item.depts()) {
                if (!departmentIds.containsKey(code)) {
                    problems.add("部门编码 " + code + " 在目标环境不存在");
                }
            }
        }
        if (!problems.isEmpty()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "角色 " + role.roleCode() + " 的数据范围无法导入：" + String.join("；", new TreeSet<>(problems)),
                    "api.project.dataScopeInvalid");
        }
        Map<String, ProjectRoleDataScopeView.Item> held = new HashMap<>();
        if (current != null) {
            dataScopes.roleScopes(projectId, current.id()).items().stream()
                    .filter(ProjectRoleDataScopeView.Item::configured)
                    .forEach(item -> held.put(item.resourceCode(), item));
        }
        List<ProjectRoleDataScopeRequest.Item> desired = new ArrayList<>();
        boolean changed = false;
        Set<String> declared = new HashSet<>();
        for (ProjectManifest.RoleDataScope item : role.dataScopes()) {
            declared.add(item.resource());
            List<String> ids = item.depts().stream()
                    .map(departmentIds::get)
                    .sorted(Comparator.comparingInt(String::length).thenComparing(Comparator.naturalOrder()))
                    .toList();
            ProjectRoleDataScopeView.Item now = held.get(item.resource());
            String before = now == null ? "SELF" : describeScope(now.scope(), now.includeChild(), now.deptIds());
            String after = describeScope(item.scope(), item.includeChild(), ids);
            draft.observe("ROLE_DS|" + role.roleCode() + "|" + item.resource() + "|" + before);
            desired.add(new ProjectRoleDataScopeRequest.Item(item.resource(), item.scope(), item.includeChild(), ids));
            if (!before.equals(after)) {
                changed = true;
                draft.access(
                        "ROLE_DATA_SCOPE",
                        role.roleCode() + "/" + item.resource(),
                        "SELF".equals(before) ? "CREATE" : "UPDATE",
                        "数据范围 " + before + " → " + after);
            }
        }
        held.keySet().stream()
                .filter(resource -> !declared.contains(resource))
                .sorted()
                .forEach(resource -> draft.change(
                        "ROLE_DATA_SCOPE", role.roleCode() + "/" + resource, "DRIFT", "目标环境多出的数据范围配置；不会撤销"));
        if (changed) {
            draft.accessOperation(created -> applyRoleDataScopes(projectId, role.roleCode(), desired, actor, md));
        }
    }

    /** 执行阶段：在角色现有配置上覆盖清单里出现的资源，其余资源原样保留，再整体保存。 */
    private void applyRoleDataScopes(
            String projectId,
            String roleCode,
            List<ProjectRoleDataScopeRequest.Item> overlay,
            KaiwuContext actor,
            RequestMetadata md) {
        ProjectRoleView role = projectService.roles(projectId).stream()
                .filter(candidate -> candidate.roleCode().equals(roleCode))
                .findFirst()
                .orElseThrow(
                        () -> new ApiException(HttpStatus.NOT_FOUND, "项目角色不存在：" + roleCode, "api.common.notFound"));
        Set<String> overridden = new HashSet<>();
        overlay.forEach(item -> overridden.add(item.resourceCode()));
        List<ProjectRoleDataScopeRequest.Item> items = new ArrayList<>();
        dataScopes.roleScopes(projectId, role.id()).items().stream()
                .filter(ProjectRoleDataScopeView.Item::configured)
                .filter(item -> !overridden.contains(item.resourceCode()))
                .forEach(item -> items.add(new ProjectRoleDataScopeRequest.Item(
                        item.resourceCode(), item.scope(), item.includeChild(), item.deptIds())));
        items.addAll(overlay);
        dataScopes.saveRoleScopes(projectId, role.id(), new ProjectRoleDataScopeRequest(items), actor, md);
    }

    /** 计划里展示和比较用的范围描述，例如 {@code CUSTOM_DEPT+CHILD[1, 2]}。 */
    private static String describeScope(String scope, boolean includeChild, List<String> deptIds) {
        if (!"CUSTOM_DEPT".equals(scope)) {
            return scope;
        }
        return scope + (includeChild ? "+CHILD" : "") + deptIds;
    }

    /** 执行阶段把授权键解析成目标项目的菜单 ID，并在角色现有授权的基础上追加。 */
    private void grant(String projectId, String roleCode, List<String> keys, KaiwuContext actor, RequestMetadata md) {
        ProjectRoleView role = projectService.roles(projectId).stream()
                .filter(candidate -> candidate.roleCode().equals(roleCode))
                .findFirst()
                .orElseThrow(
                        () -> new ApiException(HttpStatus.NOT_FOUND, "项目角色不存在：" + roleCode, "api.common.notFound"));
        Map<String, String> idByKey = new HashMap<>();
        grantKeysOfTree(projectService.menus(projectId)).forEach((id, key) -> idByKey.put(key, id));
        Set<String> menuIds = new LinkedHashSet<>(role.menuIds());
        for (String key : keys) {
            String id = idByKey.get(key);
            if (id == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "授权引用的菜单不存在：" + key, "api.common.badRequest");
            }
            menuIds.add(id);
        }
        projectService.grantRoleMenus(projectId, role.id(), menuIds, actor, md);
    }

    /** 角色清单里全部授权键：{@code perm:}、{@code route:} 与 {@code dir:} 前缀区分种类。 */
    private static List<String> desiredGrants(ProjectManifest.Role role) {
        List<String> keys = new ArrayList<>();
        role.permissions().forEach(permission -> keys.add("perm:" + permission));
        role.routes().forEach(route -> keys.add("route:" + route));
        keys.addAll(role.directories());
        return keys;
    }

    /** 平台已有菜单的授权键，键为菜单 ID。 */
    private static Map<String, String> grantKeysOfTree(List<ProjectMenuView> tree) {
        Map<String, String> result = new HashMap<>();
        collectGrantKeys(tree, "", result);
        return result;
    }

    /** 递归生成授权键；目录用名称路径，与导出一致。 */
    private static void collectGrantKeys(List<ProjectMenuView> nodes, String parentPath, Map<String, String> target) {
        if (nodes == null) {
            return;
        }
        for (ProjectMenuView node : nodes) {
            String path = parentPath.isEmpty() ? node.menuName() : parentPath + "/" + node.menuName();
            switch (node.menuType()) {
                case "BUTTON" -> target.put(node.id(), "perm:" + node.permissionCode());
                case "MENU" -> target.put(node.id(), "route:" + node.routePath());
                default -> target.put(node.id(), "dir:" + path);
            }
            collectGrantKeys(node.children(), path, target);
        }
    }

    /** 清单菜单会产生的授权键，用于校验角色授权引用的菜单本次会存在。 */
    private static Set<String> grantKeysOfManifest(List<ProjectManifest.Menu> menus, String parentPath) {
        Set<String> keys = new HashSet<>();
        for (ProjectManifest.Menu menu : menus) {
            String name = menu.name().defaultText();
            String path = parentPath.isEmpty() ? name : parentPath + "/" + name;
            switch (menu.menuType()) {
                case "BUTTON" -> keys.add("perm:" + menu.permission());
                case "MENU" -> keys.add("route:" + menu.path());
                default -> keys.add("dir:" + path);
            }
            keys.addAll(grantKeysOfManifest(menu.children(), path));
        }
        return keys;
    }

    /** 移交包内全部条目的业务键，是下一次导入识别「源环境已删除」的基线。 */
    private static Set<String> packageKeys(ProjectManifest manifest) {
        Set<String> keys = new LinkedHashSet<>();
        manifest.dicts().forEach(dict -> {
            keys.add("DICT|" + dict.dictCode());
            dict.items().forEach(item -> keys.add("DICT_ITEM|" + dict.dictCode() + ":" + item.value()));
        });
        manifest.configs().forEach(config -> keys.add("CONFIG|" + config.key()));
        collectMenuKeys(manifest.menus(), null, keys);
        manifest.roles().forEach(role -> keys.add("ROLE|" + role.roleCode()));
        manifest.jobs().forEach(job -> keys.add("JOB|" + job.jobName()));
        manifest.messages().forEach(message -> keys.add("I18N|" + message.messageKey()));
        return keys;
    }

    /** 递归收集菜单业务键，标识规则与 {@link #planMenu} 一致。 */
    private static void collectMenuKeys(List<ProjectManifest.Menu> menus, String parentIdentity, Set<String> keys) {
        for (ProjectManifest.Menu menu : menus) {
            String identity =
                    switch (menu.menuType()) {
                        case "BUTTON" -> menu.permission();
                        case "MENU" -> menu.path();
                        default ->
                            (parentIdentity == null ? "" : parentIdentity + "/")
                                    + menu.name().defaultText();
                    };
            keys.add("MENU|" + identity);
            collectMenuKeys(menu.children(), identity, keys);
        }
    }

    /** 业务键集合的摘要，计入计划哈希，基线变化后旧计划失效。 */
    private static String digestOf(Set<String> keys) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            keys.forEach(key -> digest.update((key + "\n").getBytes(StandardCharsets.UTF_8)));
            return HexFormat.of().formatHex(digest.digest());
        } catch (Exception exception) {
            throw new IllegalStateException("SHA-256 不可用", exception);
        }
    }

    /** 已有节点与清单节点是否对应：按钮看权限码，菜单看路由，目录看同一父节点下的名称。 */
    private static boolean matches(ProjectMenuView candidate, ProjectManifest.Menu menu, ParentRef parent) {
        if (!menu.menuType().equals(candidate.menuType())) {
            return false;
        }
        return switch (menu.menuType()) {
            case "BUTTON" -> menu.permission().equals(candidate.permissionCode());
            case "MENU" -> menu.path().equals(candidate.routePath());
            default ->
                menu.name().defaultText().equals(candidate.menuName())
                        && Objects.equals(candidate.parentId(), parent == null ? null : parent.existingId());
        };
    }

    /** 构造菜单保存请求；新增节点默认可见。 */
    private static ProjectMenuRequest menuRequest(ProjectManifest.Menu menu, String parentId, String nameKey) {
        return new ProjectMenuRequest(
                parentId,
                menu.name().defaultText(),
                nameKey,
                menu.menuType(),
                menu.path(),
                menu.component(),
                menu.permission(),
                menu.icon(),
                menu.sort(),
                true);
    }

    /**
     * 为多语言文本准备引用式国际化资源（ADR 0015）。
     *
     * <p>只有提供了其它语言的文本才建资源；资源已存在时保留平台上的译文，不覆盖人工改译。
     * 文本显式指定了 {@code i18nKey}（ADR 0042）时沿用该 key；只带 key 不带译文则仅引用已有资源。</p>
     *
     * @return 引用的资源 key；只有一种语言且未指定 key 时返回 null
     */
    private String referencedI18nKey(
            String generatedKey,
            ProjectManifest.Text text,
            Draft draft,
            KaiwuContext actor,
            RequestMetadata requestMetadata) {
        String key = text.messageKey() != null ? text.messageKey() : generatedKey;
        if (!text.translated() && text.messageKey() == null) {
            return null;
        }
        if (key.length() > 160) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "国际化资源 key 过长：" + key, "api.common.badRequest");
        }
        draft.referencedKeys().add(key);
        if (!text.translated()) {
            // 只引用已有 key（项目内或平台）；不存在时拒绝，避免保存出悬空引用。
            boolean referable = i18n.messageKeyExists(draft.projectId(), key);
            draft.observe("I18N|" + key + "|" + referable);
            if (!referable) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "引用的国际化资源不存在：" + key, "api.common.badRequest");
            }
            return key;
        }
        boolean exists = i18n.projectMessageKeyExists(draft.projectId(), key);
        draft.observe("I18N|" + key + "|" + exists);
        if (!exists && draft.reserveI18n(key)) {
            draft.change(
                    "I18N",
                    key,
                    "CREATE",
                    "新增国际化资源「" + text.defaultText() + "」及 "
                            + text.translations().keySet());
            String translations = objectMapper.writeValueAsString(text.translations());
            draft.operation(created -> i18n.createProjectMessage(
                    draft.projectId(),
                    new I18nMessageSaveRequest(
                            null,
                            key,
                            text.defaultText(),
                            translations,
                            "project",
                            false,
                            false,
                            "ENABLED",
                            "业务项目清单声明（ADR 0036）",
                            null),
                    actor,
                    requestMetadata));
        }
        return key;
    }

    /** 把标识里的路径分隔符等字符换成国际化 key 允许的字符。 */
    private static String safe(String value) {
        String replaced = value.replaceAll("[^A-Za-z0-9_.:-]", ".").replaceAll("\\.{2,}", ".");
        return replaced.replaceAll("^\\.|\\.$", "");
    }

    /** 当前用户缺少的同步权限。 */
    private static List<String> missingPermissions(KaiwuContext actor, ProjectManifest manifest) {
        List<String> required = new ArrayList<>(REQUIRED_PERMISSIONS);
        if (!manifest.jobs().isEmpty()) {
            required.add("system:scheduler:save");
        }
        return required.stream()
                .filter(code -> !actor.permissions().contains(code))
                .toList();
    }

    /** 展开菜单树。 */
    private static void flatten(List<ProjectMenuView> menus, List<ProjectMenuView> target) {
        if (menus == null) {
            return;
        }
        for (ProjectMenuView menu : menus) {
            target.add(menu);
            flatten(menu.children(), target);
        }
    }

    /** 漂移报告里展示的菜单标识。 */
    private static String menuIdentity(ProjectMenuView menu) {
        if (menu.permissionCode() != null && !menu.permissionCode().isBlank()) {
            return menu.permissionCode();
        }
        return menu.routePath() != null && !menu.routePath().isBlank() ? menu.routePath() : menu.menuName();
    }

    /** 计划视图。 */
    private static ProjectManifestPlanView view(
            Draft draft,
            List<String> missing,
            boolean hasBaseline,
            ProjectManifestPlanView.AlreadyApplied alreadyApplied) {
        return new ProjectManifestPlanView(
                draft.hash(), List.copyOf(draft.changes()), missing, hasBaseline, alreadyApplied);
    }

    /**
     * 父节点引用。
     *
     * @param ref        本次计划内的引用名
     * @param existingId 平台已有节点 ID；父节点是本次新增时为空
     * @param label      目录匹配用的路径标识
     */
    private record ParentRef(String ref, String existingId, String label) {

        /** 执行阶段解析父节点 ID。 */
        String resolve(Map<String, String> created) {
            return existingId != null ? existingId : created.get(ref);
        }
    }

    /**
     * 待执行的操作。
     *
     * @param category NORMAL 随计划执行；ACCESS 需勾选导入授权；DELETE 需逐项勾选
     * @param key      DELETE 类的勾选标识（{@code 资源|标识}），其余为空
     * @param order    DELETE 类的执行顺序，小的先执行
     * @param run      操作本体，接收「引用 → 平台 ID」表
     */
    private record Operation(String category, String key, int order, Consumer<Map<String, String>> run) {}

    /**
     * 计算中的计划：变化条目与按顺序执行的操作。
     *
     * <p>操作接收一张"引用 → 平台 ID"的表，用来把新建的字典类型与菜单父节点传给后续操作。
     * {@code basis} 记录清单涉及的平台条目在计划时的状态，计入哈希：计划之后这些条目被改动，
     * 执行时重新计算的哈希就会不同。{@code baseline} 是上次成功移交的业务键，平台上多出的条目
     * 若在其中，说明是源环境删除的，列为可删除项，否则只是目标环境自己加的漂移。</p>
     */
    private record Draft(
            String projectId,
            Set<String> baseline,
            List<ProjectManifestPlanView.Change> changes,
            List<Operation> operations,
            List<String> basis,
            Set<String> referencedKeys) {

        /** 记录一个参与比较的平台条目当前状态。 */
        void observe(String state) {
            basis.add(state);
        }

        /** 记录一条普通变化。 */
        void change(String resource, String key, String action, String detail) {
            changes.add(new ProjectManifestPlanView.Change(resource, key, action, detail));
        }

        /** 记录一条授权类变化，勾选导入授权才执行。 */
        void access(String resource, String key, String action, String detail) {
            changes.add(new ProjectManifestPlanView.Change(resource, key, action, detail, "ACCESS"));
        }

        /** 追加一个随计划执行的操作。 */
        void operation(Consumer<Map<String, String>> operation) {
            operations.add(new Operation("NORMAL", null, 0, operation));
        }

        /** 追加一个授权类操作。 */
        void accessOperation(Consumer<Map<String, String>> operation) {
            operations.add(new Operation("ACCESS", null, 0, operation));
        }

        /**
         * 平台上存在而清单未声明的条目：上次移交的基线里有它，说明是源环境删除的，列为可删除项；
         * 否则只报告漂移，不会删除。
         */
        void drift(String resource, String key, int order, Runnable deleter) {
            String businessKey = resource + "|" + key;
            if (baseline.contains(businessKey)) {
                changes.add(new ProjectManifestPlanView.Change(
                        resource, key, "REMOVED_AT_SOURCE", "上次移交时存在、本次移交包已没有；勾选后才会删除", "DELETE"));
                operations.add(new Operation("DELETE", businessKey, order, created -> deleter.run()));
            } else {
                change(resource, key, "DRIFT", "平台上存在、清单未声明；不会删除");
            }
        }

        /** 同一 key 在一份计划内只新增一次。 */
        boolean reserveI18n(String key) {
            return changes.stream()
                    .noneMatch(change ->
                            "I18N".equals(change.resource()) && change.key().equals(key));
        }

        /** 计划摘要：覆盖每条变化，以及清单涉及的平台条目在计划时的状态。 */
        String hash() {
            try {
                MessageDigest digest = MessageDigest.getInstance("SHA-256");
                for (ProjectManifestPlanView.Change change : changes) {
                    digest.update((change.resource() + "|" + change.key() + "|" + change.action() + "|"
                                    + change.detail() + "|" + change.category() + "\n")
                            .getBytes(StandardCharsets.UTF_8));
                }
                for (String state : basis) {
                    digest.update((state + "\n").getBytes(StandardCharsets.UTF_8));
                }
                return HexFormat.of().formatHex(digest.digest());
            } catch (Exception exception) {
                throw new IllegalStateException("SHA-256 不可用", exception);
            }
        }
    }
}
