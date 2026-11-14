package com.kaiwu.module.factory.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageResult;
import com.kaiwu.module.configuration.service.I18nService;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.factory.convert.ProjectManifestParser;
import com.kaiwu.module.factory.model.ProjectManifest;
import com.kaiwu.module.factory.service.ProjectManifestExportService;
import com.kaiwu.module.factory.vo.ProjectManifestExportView;
import com.kaiwu.module.i18n.vo.I18nMessageView;
import com.kaiwu.module.metadata.vo.ConfigView;
import com.kaiwu.module.metadata.vo.DictItemView;
import com.kaiwu.module.metadata.vo.DictTypeView;
import com.kaiwu.module.operation.service.ProjectSchedulerService;
import com.kaiwu.module.operation.vo.SchedulerJobView;
import com.kaiwu.module.project.service.ProjectDataScopeService;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.vo.ProjectMenuView;
import com.kaiwu.module.project.vo.ProjectRoleDataScopeView;
import com.kaiwu.module.project.vo.ProjectRoleView;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.port.ProjectGenerationProjectPort;
import com.kaiwu.starter.KaiwuContext;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import org.springframework.stereotype.Service;
import org.yaml.snakeyaml.DumperOptions;
import org.yaml.snakeyaml.Yaml;
import tools.jackson.databind.ObjectMapper;

/**
 * 项目配置移交包导出实现（ADR 0042）。
 *
 * <p>只读，不开事务写入。输出格式与 {@link ProjectManifestParser} 接受的清单一致，导出再导入应得到零变更；
 * 平台无法用清单表达的内容（停用状态、字典继承、敏感配置等）不静默丢弃，而是写入 {@code warnings}。</p>
 */
@Service
public class ProjectManifestExportServiceImpl implements ProjectManifestExportService {

    /** 移交包格式版本。 */
    static final int FORMAT_VERSION = 1;

    private final ProjectGenerationProjectPort projects;
    private final ProjectService projectService;
    private final MetadataService metadata;
    private final I18nService i18n;
    private final ObjectMapper objectMapper;
    private final ProjectSchedulerService scheduler;
    private final ProjectDataScopeService dataScopes;

    /** 注入被复用的只读查询服务。 */
    public ProjectManifestExportServiceImpl(
            ProjectGenerationProjectPort projects,
            ProjectService projectService,
            MetadataService metadata,
            I18nService i18n,
            ObjectMapper objectMapper,
            ProjectSchedulerService scheduler,
            ProjectDataScopeService dataScopes) {
        this.projects = projects;
        this.projectService = projectService;
        this.metadata = metadata;
        this.i18n = i18n;
        this.objectMapper = objectMapper;
        this.scheduler = scheduler;
        this.dataScopes = dataScopes;
    }

    /** 导出全量快照；调用者必须是该项目的有效项目管理员。 */
    @Override
    public ProjectManifestExportView export(String projectId, KaiwuContext actor, String sourceHost) {
        ProjectView project = projects.requireProjectAdmin(projectId, actor.userId());
        Map<String, I18nMessageView> messages = new HashMap<>();
        i18n.projectMessages(project.id()).forEach(message -> messages.put(message.messageKey(), message));
        List<String> warnings = new ArrayList<>();

        List<Map<String, Object>> dicts = dicts(project.id(), messages, warnings);
        List<Map<String, Object>> configs = configs(project.id(), warnings);
        List<ProjectMenuView> menuTree = projectService.menus(project.id());
        List<Map<String, Object>> menus = menus(menuTree, messages, warnings);
        List<Map<String, Object>> roles = roles(project.id(), menuTree);

        Map<String, String> files = new LinkedHashMap<>();
        files.put("dicts.yml", dump(dicts));
        files.put("configs.yml", dump(configs));
        files.put("menus.yml", dump(menus));
        files.put("roles.yml", dump(roles));
        List<Map<String, Object>> jobs = jobs(project.id(), actor, warnings);
        List<Map<String, Object>> i18nRows = messages(project.id(), warnings);
        files.put("jobs.yml", dump(jobs));
        files.put("i18n.yml", dump(i18nRows));

        Map<String, Integer> stats = new LinkedHashMap<>();
        stats.put("dicts", dicts.size());
        stats.put("configs", configs.size());
        stats.put("menus", countMenus(menus));
        stats.put("roles", roles.size());
        stats.put("jobs", jobs.size());
        stats.put("i18n", i18nRows.size());
        return new ProjectManifestExportView(
                FORMAT_VERSION,
                project.projectCode(),
                new ProjectManifestExportView.Source(
                        sourceHost, actor.userId(), Instant.now().toString()),
                digest(files),
                stats,
                List.copyOf(warnings),
                files);
    }

    /** 字典类型与字典项；只导出本项目作用域，全局字典归平台。 */
    private List<Map<String, Object>> dicts(
            String projectId, Map<String, I18nMessageView> messages, List<String> warnings) {
        List<DictTypeView> types = metadata.dictTypes(projectId).stream()
                .filter(type -> projectId.equals(type.scopeId()))
                .sorted(Comparator.comparingInt(DictTypeView::sortNo).thenComparing(DictTypeView::dictCode))
                .toList();
        List<Map<String, Object>> result = new ArrayList<>();
        for (DictTypeView type : types) {
            List<DictItemView> items = metadata.dictItems(projectId, type.id()).stream()
                    .sorted(Comparator.comparingInt(DictItemView::sortNo).thenComparing(DictItemView::itemValue))
                    .toList();
            if (items.isEmpty()) {
                warnings.add("字典 " + type.dictCode() + " 没有字典项，清单要求至少一项，未导出");
                continue;
            }
            if (type.inheritGlobal()) {
                warnings.add("字典 " + type.dictCode() + " 继承全局字典，清单不表达继承，导入后需手工开启");
            }
            if (!"ENABLED".equals(type.status())) {
                warnings.add("字典 " + type.dictCode() + " 状态为 " + type.status() + "，导入后为启用");
            }
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("dictCode", type.dictCode());
            row.put("name", text(type.dictName(), type.dictNameKey(), messages, warnings));
            putIfPresent(row, "description", type.description());
            List<Map<String, Object>> itemRows = new ArrayList<>();
            for (DictItemView item : items) {
                if (!"ENABLED".equals(item.status())) {
                    warnings.add(
                            "字典项 " + type.dictCode() + ":" + item.itemValue() + " 状态为 " + item.status() + "，导入后为启用");
                }
                if (item.extraJson() != null && !item.extraJson().isBlank()) {
                    warnings.add("字典项 " + type.dictCode() + ":" + item.itemValue() + " 有扩展属性，清单不表达");
                }
                Map<String, Object> itemRow = new LinkedHashMap<>();
                itemRow.put("value", item.itemValue());
                itemRow.put("label", text(item.itemLabel(), item.labelI18nKey(), messages, warnings));
                putIfPresent(itemRow, "color", item.color());
                itemRow.put("sort", item.sortNo());
                if (item.defaultItem()) {
                    itemRow.put("default", true);
                }
                itemRows.add(itemRow);
            }
            row.put("items", itemRows);
            result.add(row);
        }
        return result;
    }

    /**
     * 定时任务：业务键是任务名；同名任务有歧义，整组不导出并说明。启用状态仅供参考，导入时新建一律停用。
     *
     * <p>调用者不是项目成员时调度服务会拒绝读取，这里不让它拖垮整个导出，改为警告。</p>
     */
    private List<Map<String, Object>> jobs(String projectId, KaiwuContext actor, List<String> warnings) {
        List<SchedulerJobView> all = new ArrayList<>();
        try {
            long page = 1;
            while (true) {
                PageResult<SchedulerJobView> current = scheduler.jobs(projectId, page, 100, actor);
                all.addAll(current.records());
                if (current.records().isEmpty() || all.size() >= current.total()) {
                    break;
                }
                page++;
            }
        } catch (ApiException exception) {
            warnings.add("定时任务未导出：" + exception.getMessage());
            return List.of();
        }
        Map<String, Long> counts = new HashMap<>();
        all.forEach(job -> counts.merge(job.jobName(), 1L, Long::sum));
        List<Map<String, Object>> result = new ArrayList<>();
        all.stream().sorted(Comparator.comparing(SchedulerJobView::jobName)).forEach(job -> {
            if (counts.get(job.jobName()) > 1) {
                warnings.add("定时任务 " + job.jobName() + " 存在同名任务，业务键有歧义，未导出");
                return;
            }
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("jobName", job.jobName());
            row.put("taskType", job.taskType());
            row.put("cron", job.cronExpression());
            row.put("zoneId", job.zoneId());
            putIfPresent(row, "payload", job.payload());
            row.put("enabled", job.enabled());
            result.add(row);
        });
        return result;
    }

    /** 项目国际化资源：全部导出，包含被字典、菜单引用的；目标环境按 key 对齐。 */
    private List<Map<String, Object>> messages(String projectId, List<String> warnings) {
        List<Map<String, Object>> result = new ArrayList<>();
        i18n.projectMessages(projectId).stream()
                .sorted(Comparator.comparing(I18nMessageView::messageKey))
                .forEach(message -> {
                    if (!"ENABLED".equals(message.status())) {
                        warnings.add("国际化资源 " + message.messageKey() + " 状态为 " + message.status() + "，导入后为启用");
                    }
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("messageKey", message.messageKey());
                    row.put("zh-CN", message.defaultText());
                    translations(message.translationsJson()).forEach((locale, text) -> {
                        if (!"zh-CN".equals(locale)) {
                            row.put(locale, text);
                        }
                    });
                    putIfPresent(row, "description", message.description());
                    result.add(row);
                });
        return result;
    }

    /** 参数配置；敏感项不导出，当前值作为目标环境首次创建时的初始值。 */
    private List<Map<String, Object>> configs(String projectId, List<String> warnings) {
        List<ConfigView> configs = metadata.configs(projectId).stream()
                .filter(config -> projectId.equals(config.scopeId()))
                .sorted(Comparator.comparing(ConfigView::configKey))
                .toList();
        List<Map<String, Object>> result = new ArrayList<>();
        for (ConfigView config : configs) {
            if (config.secret()) {
                warnings.add("配置 " + config.configKey() + " 是敏感项，未导出");
                continue;
            }
            if (config.valueI18nKey() != null && !config.valueI18nKey().isBlank()) {
                warnings.add("配置 " + config.configKey() + " 的值引用了国际化资源，清单不表达，仅导出当前文本");
            }
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("key", config.configKey());
            row.put("type", config.valueType());
            putIfPresent(row, "default", config.configValue());
            putIfPresent(row, "description", config.description());
            result.add(row);
        }
        return result;
    }

    /** 菜单树；建项目时种入的成员、角色、文件节点不导出。 */
    private List<Map<String, Object>> menus(
            List<ProjectMenuView> tree, Map<String, I18nMessageView> messages, List<String> warnings) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (ProjectMenuView menu : sorted(tree)) {
            if ("MENU".equals(menu.menuType()) && ProjectManifest.SEEDED_MENU_ROUTES.contains(menu.routePath())) {
                continue;
            }
            result.add(menuRow(menu, messages, warnings));
        }
        return result;
    }

    /** 递归生成一个菜单节点。 */
    private Map<String, Object> menuRow(
            ProjectMenuView menu, Map<String, I18nMessageView> messages, List<String> warnings) {
        if (!menu.visible() || !"ENABLED".equals(menu.status())) {
            warnings.add("菜单 " + identity(menu) + " 被隐藏或停用，导入后为可见并启用");
        }
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("type", menu.menuType());
        row.put("name", text(menu.menuName(), menu.menuNameKey(), messages, warnings));
        putIfPresent(row, "path", menu.routePath());
        putIfPresent(row, "component", menu.componentPath());
        putIfPresent(row, "permission", menu.permissionCode());
        putIfPresent(row, "icon", menu.icon());
        row.put("sort", menu.sortNo());
        List<Map<String, Object>> children = new ArrayList<>();
        for (ProjectMenuView child : sorted(menu.children())) {
            children.add(menuRow(child, messages, warnings));
        }
        if (!children.isEmpty()) {
            row.put("children", children);
        }
        return row;
    }

    /**
     * 自定义角色及授权，授权用业务键表示：按钮用权限码，页面用路由，目录用名称路径。
     *
     * <p>内置 project-admin 不导出；成员不导出。授权在 MR1 只导出，导入由后续计划处理。</p>
     */
    private List<Map<String, Object>> roles(String projectId, List<ProjectMenuView> tree) {
        Map<String, MenuKey> keyById = new HashMap<>();
        index(tree, "", keyById);
        List<Map<String, Object>> result = new ArrayList<>();
        List<ProjectRoleView> roles = projectService.roles(projectId).stream()
                .filter(role -> !role.builtIn())
                .sorted(Comparator.comparing(ProjectRoleView::roleCode))
                .toList();
        for (ProjectRoleView role : roles) {
            Set<String> permissions = new TreeSet<>();
            Set<String> routes = new TreeSet<>();
            Set<String> directories = new TreeSet<>();
            for (String menuId : role.menuIds() == null ? Set.<String>of() : role.menuIds()) {
                MenuKey key = keyById.get(menuId);
                if (key == null) {
                    continue;
                }
                switch (key.type()) {
                    case "BUTTON" -> permissions.add(key.value());
                    case "MENU" -> routes.add(key.value());
                    default -> directories.add(key.value());
                }
            }
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("roleCode", role.roleCode());
            row.put("name", role.roleName());
            putIfPresent(row, "description", role.description());
            row.put("status", role.status());
            row.put("permissions", new ArrayList<>(permissions));
            row.put("routes", new ArrayList<>(routes));
            row.put("directories", new ArrayList<>(directories));
            List<Map<String, Object>> scopes = roleDataScopes(projectId, role);
            if (!scopes.isEmpty()) {
                row.put("dataScopes", scopes);
            }
            result.add(row);
        }
        return result;
    }

    /**
     * 角色的数据范围（ADR 0044）：只导出显式配置且不是仅本人的资源，省略的资源导入时等价于仅本人。
     * 指定部门用部门编码表示，部门 ID 在各环境不同。
     */
    private List<Map<String, Object>> roleDataScopes(String projectId, ProjectRoleView role) {
        List<ProjectRoleDataScopeView.Item> configured = dataScopes.roleScopes(projectId, role.id()).items().stream()
                .filter(ProjectRoleDataScopeView.Item::configured)
                .filter(item -> !"SELF".equals(item.scope()))
                .toList();
        Set<String> departmentIds = new TreeSet<>();
        configured.forEach(item -> departmentIds.addAll(item.deptIds()));
        Map<String, String> codeById = dataScopes.departmentCodesById(departmentIds);
        List<Map<String, Object>> result = new ArrayList<>();
        for (ProjectRoleDataScopeView.Item item : configured) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("resource", item.resourceCode());
            row.put("scope", item.scope());
            if ("CUSTOM_DEPT".equals(item.scope())) {
                if (item.includeChild()) {
                    row.put("includeChild", true);
                }
                row.put(
                        "depts",
                        item.deptIds().stream()
                                .map(codeById::get)
                                .filter(Objects::nonNull)
                                .sorted()
                                .toList());
            }
            result.add(row);
        }
        return result;
    }

    /** 建立菜单 ID 到业务键的索引；没有权限码、路由的节点按名称路径标识。 */
    private static void index(List<ProjectMenuView> nodes, String parentPath, Map<String, MenuKey> target) {
        if (nodes == null) {
            return;
        }
        for (ProjectMenuView node : nodes) {
            String path = parentPath.isEmpty() ? node.menuName() : parentPath + "/" + node.menuName();
            switch (node.menuType()) {
                case "BUTTON" -> target.put(node.id(), new MenuKey("BUTTON", node.permissionCode()));
                case "MENU" -> target.put(node.id(), new MenuKey("MENU", node.routePath()));
                default -> target.put(node.id(), new MenuKey("DIRECTORY", "dir:" + path));
            }
            index(node.children(), path, target);
        }
    }

    /**
     * 多语言文本：未引用国际化资源时是普通字符串；引用资源时带 {@code i18nKey}，项目内资源附带全部译文。
     *
     * <p>引用的是平台资源（项目内没有该 key）时只带 key 与当前文本，导入时按 key 引用目标环境的平台资源。</p>
     */
    private Object text(String fallback, String key, Map<String, I18nMessageView> messages, List<String> warnings) {
        if (key == null || key.isBlank()) {
            return fallback;
        }
        I18nMessageView message = messages.get(key);
        Map<String, Object> text = new LinkedHashMap<>();
        text.put(ProjectManifestParser.I18N_KEY_FIELD, key);
        if (message == null) {
            text.put("zh-CN", fallback);
            return text;
        }
        text.put("zh-CN", message.defaultText());
        Map<String, String> translations = translations(message.translationsJson());
        translations.entrySet().stream()
                .filter(entry -> !"zh-CN".equals(entry.getKey()))
                .forEach(entry -> text.put(entry.getKey(), entry.getValue()));
        if (translations.keySet().stream().allMatch("zh-CN"::equals)) {
            warnings.add("国际化资源 " + key + " 没有其它语言译文，目标环境需已存在同名资源才能导入");
        }
        return text;
    }

    /** 解析资源的译文 JSON；格式异常按无译文处理。 */
    private Map<String, String> translations(String json) {
        Map<String, String> result = new TreeMap<>();
        if (json == null || json.isBlank()) {
            return result;
        }
        try {
            Map<?, ?> parsed = objectMapper.readValue(json, Map.class);
            parsed.forEach((locale, value) -> {
                if (value instanceof String translated && !translated.isBlank()) {
                    result.put(String.valueOf(locale), translated);
                }
            });
        } catch (RuntimeException exception) {
            return new TreeMap<>();
        }
        return result;
    }

    /** 同级节点按排序号、名称稳定排序，保证两次导出一致。 */
    private static List<ProjectMenuView> sorted(List<ProjectMenuView> nodes) {
        if (nodes == null) {
            return List.of();
        }
        return nodes.stream()
                .sorted(Comparator.comparingInt(ProjectMenuView::sortNo)
                        .thenComparing(menu -> String.valueOf(menu.menuName())))
                .toList();
    }

    /** 警告里展示的菜单标识。 */
    private static String identity(ProjectMenuView menu) {
        if (menu.permissionCode() != null && !menu.permissionCode().isBlank()) {
            return menu.permissionCode();
        }
        return menu.routePath() != null && !menu.routePath().isBlank() ? menu.routePath() : menu.menuName();
    }

    /** 统计菜单节点总数（含按钮）。 */
    @SuppressWarnings("unchecked")
    private static int countMenus(List<Map<String, Object>> menus) {
        int count = 0;
        for (Map<String, Object> menu : menus) {
            count += 1;
            Object children = menu.get("children");
            if (children instanceof List<?> list) {
                count += countMenus((List<Map<String, Object>>) list);
            }
        }
        return count;
    }

    /** 非空才写入。 */
    private static void putIfPresent(Map<String, Object> row, String field, String value) {
        if (value != null && !value.isBlank()) {
            row.put(field, value);
        }
    }

    /** 输出块状 YAML；空列表输出空文本，导入时视为未提供。 */
    private static String dump(List<Map<String, Object>> rows) {
        if (rows.isEmpty()) {
            return "";
        }
        DumperOptions options = new DumperOptions();
        options.setDefaultFlowStyle(DumperOptions.FlowStyle.BLOCK);
        options.setAllowUnicode(true);
        options.setWidth(120);
        options.setIndent(2);
        options.setIndicatorIndent(0);
        return new Yaml(options).dump(rows);
    }

    /** 文件名与内容的摘要，按文件名排序后计算。 */
    private static String digest(Map<String, String> files) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            for (Map.Entry<String, String> file : new TreeMap<>(files).entrySet()) {
                digest.update(file.getKey().getBytes(StandardCharsets.UTF_8));
                digest.update((byte) 0);
                digest.update(file.getValue().getBytes(StandardCharsets.UTF_8));
                digest.update((byte) 0);
            }
            return HexFormat.of().formatHex(digest.digest());
        } catch (Exception exception) {
            throw new IllegalStateException("SHA-256 不可用", exception);
        }
    }

    /**
     * 菜单的业务键。
     *
     * @param type  BUTTON / MENU / DIRECTORY
     * @param value 权限码、路由，或 {@code dir:} 加名称路径
     */
    private record MenuKey(String type, String value) {}
}
