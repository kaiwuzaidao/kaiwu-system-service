package com.kaiwu.module.factory.convert;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.factory.model.ProjectManifest;
import com.kaiwu.module.project.model.DataScopeType;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.support.CronExpression;
import org.springframework.stereotype.Component;
import org.yaml.snakeyaml.LoaderOptions;
import org.yaml.snakeyaml.Yaml;
import org.yaml.snakeyaml.constructor.SafeConstructor;
import org.yaml.snakeyaml.error.YAMLException;
import tools.jackson.databind.json.JsonMapper;

/**
 * 把业务仓 {@code kaiwu/*.yml} 解析为 {@link ProjectManifest}（ADR 0036）。
 *
 * <p>只用 {@link SafeConstructor} 得到基础类型，不实例化任何自定义类；限制别名数量与文本长度，
 * 防止构造超大文档。校验失败一律返回 400，消息指出文件与条目位置，供 CLI 原样展示。</p>
 */
@Component
public class ProjectManifestParser {

    /** 允许的清单文件名。 */
    public static final Set<String> FILES =
            Set.of("dicts.yml", "configs.yml", "menus.yml", "roles.yml", "jobs.yml", "i18n.yml", "data-scopes.yml");

    private static final Pattern CODE = Pattern.compile("[A-Za-z][A-Za-z0-9_.:-]{1,127}");
    private static final Pattern VALUE_TYPE = Pattern.compile("STRING|NUMBER|BOOLEAN|JSON");
    private static final Pattern MENU_TYPE = Pattern.compile("DIRECTORY|MENU|BUTTON");
    private static final Pattern LOCALE = Pattern.compile("[a-z]{2,3}(-[A-Z][a-z]{3})?(-[A-Z]{2}|-[0-9]{3})?");
    private static final Pattern SENSITIVE_KEY =
            Pattern.compile("(?i).*(password|passwd|secret|token|credential|private[-_.]?key|api[-_.]?key).*");
    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final Pattern ROLE_CODE = Pattern.compile("[a-z][a-z0-9-]{1,63}");
    private static final int MAX_DOCUMENT_CHARS = 200_000;
    private static final int MAX_GRANTS = 1000;
    /** 国际化资源一个项目可能有上千条，文件上限放宽。 */
    private static final int MAX_I18N_DOCUMENT_CHARS = 1_000_000;

    private static final Pattern MESSAGE_KEY = Pattern.compile("[A-Za-z][A-Za-z0-9_.:-]{1,159}");
    private static final int MAX_MESSAGE_TEXT = 2000;
    private static final int MAX_JOB_PAYLOAD = 10_000;

    private static final Pattern DATA_RESOURCE_CODE = Pattern.compile("[a-z][a-z0-9_-]*:[a-z][a-z0-9_-]*");
    private static final Pattern SQL_IDENTIFIER = Pattern.compile("[a-z][a-z0-9_]*");
    private static final Set<String> DATA_SCOPE_TOP_KEYS = Set.of("resources", "exempt");
    private static final Set<String> DATA_RESOURCE_FIELDS =
            Set.of("code", "name", "table", "ownerUserColumn", "ownerDeptColumn", "allowedScopes");
    private static final Set<String> DATA_EXEMPT_FIELDS = Set.of("table", "reason");
    private static final Set<String> ROLE_DATA_SCOPE_FIELDS = Set.of("resource", "scope", "depts", "includeChild");
    private static final int MAX_ROLE_SCOPE_DEPARTMENTS = 128;
    /** 这些字段属于授权，清单里出现时给出专门提示而不是笼统的"不支持"。 */
    private static final Set<String> DATA_SCOPE_GRANT_FIELDS =
            Set.of("defaultScope", "defaultScopes", "roles", "grants", "scope", "scopes");

    /** 多语言文本里显式指定国际化资源 key 的字段名；不满足语言代码格式，不会与语言冲突。 */
    public static final String I18N_KEY_FIELD = "i18nKey";

    /** 解析全部文件；未提供的文件视为空列表。 */
    public ProjectManifest parse(Map<String, String> files) {
        for (String name : files.keySet()) {
            if (!FILES.contains(name)) {
                throw invalid(
                        name,
                        "不支持的清单文件，只接受 dicts.yml、configs.yml、menus.yml、roles.yml、jobs.yml、i18n.yml、data-scopes.yml");
            }
        }
        List<ProjectManifest.DictType> dicts = new ArrayList<>();
        List<Map<String, Object>> rawDicts = list(files, "dicts.yml");
        Set<String> dictCodes = new HashSet<>();
        for (int index = 0; index < rawDicts.size(); index++) {
            ProjectManifest.DictType dict = dict("dicts.yml#" + (index + 1), rawDicts.get(index));
            if (!dictCodes.add(dict.dictCode())) {
                throw invalid("dicts.yml#" + (index + 1), "字典编码重复：" + dict.dictCode());
            }
            dicts.add(dict);
        }
        List<ProjectManifest.Config> configs = new ArrayList<>();
        List<Map<String, Object>> rawConfigs = list(files, "configs.yml");
        Set<String> configKeys = new HashSet<>();
        for (int index = 0; index < rawConfigs.size(); index++) {
            ProjectManifest.Config config = config("configs.yml#" + (index + 1), rawConfigs.get(index));
            if (!configKeys.add(config.key())) {
                throw invalid("configs.yml#" + (index + 1), "配置键重复：" + config.key());
            }
            configs.add(config);
        }
        List<ProjectManifest.Menu> menus = new ArrayList<>();
        List<Map<String, Object>> rawMenus = list(files, "menus.yml");
        Set<String> permissions = new HashSet<>();
        for (int index = 0; index < rawMenus.size(); index++) {
            menus.add(menu("menus.yml#" + (index + 1), rawMenus.get(index), permissions));
        }
        List<ProjectManifest.Role> roles = new ArrayList<>();
        List<Map<String, Object>> rawRoles = list(files, "roles.yml");
        Set<String> roleCodes = new HashSet<>();
        for (int index = 0; index < rawRoles.size(); index++) {
            ProjectManifest.Role role = role("roles.yml#" + (index + 1), rawRoles.get(index));
            if (!roleCodes.add(role.roleCode())) {
                throw invalid("roles.yml#" + (index + 1), "角色编码重复：" + role.roleCode());
            }
            roles.add(role);
        }
        List<ProjectManifest.Job> jobs = new ArrayList<>();
        List<Map<String, Object>> rawJobs = list(files, "jobs.yml");
        Set<String> jobNames = new HashSet<>();
        for (int index = 0; index < rawJobs.size(); index++) {
            ProjectManifest.Job job = job("jobs.yml#" + (index + 1), rawJobs.get(index));
            if (!jobNames.add(job.jobName())) {
                throw invalid("jobs.yml#" + (index + 1), "任务名重复：" + job.jobName());
            }
            jobs.add(job);
        }
        List<ProjectManifest.Message> messages = new ArrayList<>();
        List<Map<String, Object>> rawMessages = list(files, "i18n.yml");
        Set<String> messageKeys = new HashSet<>();
        for (int index = 0; index < rawMessages.size(); index++) {
            ProjectManifest.Message message = message("i18n.yml#" + (index + 1), rawMessages.get(index));
            if (!messageKeys.add(message.messageKey())) {
                throw invalid("i18n.yml#" + (index + 1), "国际化资源 key 重复：" + message.messageKey());
            }
            messages.add(message);
        }
        return new ProjectManifest(
                List.copyOf(dicts),
                List.copyOf(configs),
                List.copyOf(menus),
                List.copyOf(roles),
                List.copyOf(jobs),
                List.copyOf(messages),
                dataScopes(files));
    }

    /** 读取并解析一个 YAML 文件，空文件返回空；统一的大小、别名和重复键限制。 */
    private static Object loadYaml(Map<String, String> files, String name) {
        String content = files.get(name);
        if (content == null || content.isBlank()) {
            return null;
        }
        int limit = "i18n.yml".equals(name) ? MAX_I18N_DOCUMENT_CHARS : MAX_DOCUMENT_CHARS;
        if (content.length() > limit) {
            throw invalid(name, "文件过大");
        }
        LoaderOptions options = new LoaderOptions();
        options.setMaxAliasesForCollections(20);
        options.setAllowDuplicateKeys(false);
        options.setCodePointLimit(limit);
        try {
            return new Yaml(new SafeConstructor(options)).load(content);
        } catch (YAMLException exception) {
            throw invalid(name, "YAML 语法错误：" + firstLine(exception.getMessage()));
        }
    }

    /**
     * 解析 {@code data-scopes.yml}（docs/DATA_SCOPE.md §2）。
     *
     * <p>顶层是带 {@code resources} 与 {@code exempt} 的对象，与其它清单的顶层列表不同。{@code exempt} 只供业务仓
     * 的门禁使用，平台校验后丢弃。未知字段一律报错，授权类字段给出专门提示：授权不随代码下发（ADR 0036、ADR 0044）。</p>
     */
    private static List<ProjectManifest.DataResource> dataScopes(Map<String, String> files) {
        String name = "data-scopes.yml";
        Object document = loadYaml(files, name);
        if (document == null) {
            return List.of();
        }
        if (!(document instanceof Map<?, ?> top)) {
            throw invalid(name, "顶层必须是对象，包含 resources 与可选的 exempt");
        }
        for (Object key : top.keySet()) {
            if (!DATA_SCOPE_TOP_KEYS.contains(String.valueOf(key))) {
                throw invalid(name, "不支持的顶层字段 " + key + "，只接受 resources、exempt");
            }
        }
        List<ProjectManifest.DataResource> resources = new ArrayList<>();
        Set<String> codes = new HashSet<>();
        Set<String> tables = new HashSet<>();
        Object rawResources = top.get("resources");
        if (rawResources != null && !(rawResources instanceof List<?>)) {
            throw invalid(name + "#resources", "必须是列表");
        }
        List<?> rows = rawResources == null ? List.of() : (List<?>) rawResources;
        for (int index = 0; index < rows.size(); index++) {
            String at = name + "#resources" + (index + 1);
            if (!(rows.get(index) instanceof Map<?, ?> row)) {
                throw invalid(at, "每一项必须是对象");
            }
            ProjectManifest.DataResource resource = dataResource(at, (Map<String, Object>) row);
            if (!codes.add(resource.code())) {
                throw invalid(at, "资源码重复：" + resource.code());
            }
            if (!tables.add(resource.table())) {
                throw invalid(at, "表名重复：" + resource.table());
            }
            resources.add(resource);
        }
        dataScopeExemptions(name, top.get("exempt"), tables);
        return List.copyOf(resources);
    }

    /** 解析单个受控资源；字段、取值与组合规则见契约文档。 */
    private static ProjectManifest.DataResource dataResource(String at, Map<String, Object> row) {
        for (String field : row.keySet()) {
            if (DATA_SCOPE_GRANT_FIELDS.contains(field)) {
                throw invalid(at, "清单不得声明授权字段 " + field + "：授权不随代码下发，请在角色页配置（ADR 0044）");
            }
            if (!DATA_RESOURCE_FIELDS.contains(field)) {
                throw invalid(at, "不支持的字段 " + field);
            }
        }
        String code = string(at, row, "code", true, 128);
        if (!DATA_RESOURCE_CODE.matcher(code).matches()) {
            throw invalid(at, "code 格式应为 模块:资源，且只含小写字母、数字、下划线和连字符：" + code);
        }
        String table = string(at, row, "table", true, 64);
        String userColumn = string(at, row, "ownerUserColumn", false, 64);
        String deptColumn = string(at, row, "ownerDeptColumn", false, 64);
        userColumn = userColumn == null ? "owner_user_id" : userColumn;
        deptColumn = deptColumn == null ? "owner_dept_id" : deptColumn;
        for (String identifier : List.of(table, userColumn, deptColumn)) {
            if (!SQL_IDENTIFIER.matcher(identifier).matches()) {
                throw invalid(at, "表名或列名只能是小写字母、数字和下划线，且以字母开头：" + identifier);
            }
        }
        if (userColumn.equals(deptColumn)) {
            throw invalid(at, "ownerUserColumn 与 ownerDeptColumn 不能相同");
        }
        return new ProjectManifest.DataResource(
                code,
                string(at, row, "name", true, 100),
                table,
                userColumn,
                deptColumn,
                allowedScopes(at, row.get("allowedScopes")));
    }

    /** 解析 {@code allowedScopes}：非空、取值合法、去重、必含 SELF，按枚举顺序输出。 */
    private static List<String> allowedScopes(String at, Object raw) {
        if (!(raw instanceof List<?> values) || values.isEmpty()) {
            throw invalid(at, "allowedScopes 必须是非空列表");
        }
        Set<String> given = new LinkedHashSet<>();
        for (Object value : values) {
            if (!(value instanceof String text) || DataScopeType.parse(text).isEmpty()) {
                throw invalid(at, "allowedScopes 含无效范围类型：" + value);
            }
            if (!given.add(text)) {
                throw invalid(at, "allowedScopes 含重复项：" + text);
            }
        }
        if (!given.contains(DataScopeType.SELF.name())) {
            throw invalid(at, "allowedScopes 必须包含 SELF：未配置的角色固定为仅本人");
        }
        List<String> ordered = new ArrayList<>();
        for (DataScopeType type : DataScopeType.values()) {
            if (given.contains(type.name())) {
                ordered.add(type.name());
            }
        }
        return List.copyOf(ordered);
    }

    /** 校验 {@code exempt}：每项有表名与理由，且不与受控资源冲突、不重复。 */
    private static void dataScopeExemptions(String name, Object raw, Set<String> controlledTables) {
        if (raw == null) {
            return;
        }
        if (!(raw instanceof List<?> rows)) {
            throw invalid(name + "#exempt", "必须是列表");
        }
        Set<String> seen = new HashSet<>();
        for (int index = 0; index < rows.size(); index++) {
            String at = name + "#exempt" + (index + 1);
            if (!(rows.get(index) instanceof Map<?, ?> row)) {
                throw invalid(at, "每一项必须是对象");
            }
            Map<String, Object> fields = (Map<String, Object>) row;
            for (String field : fields.keySet()) {
                if (!DATA_EXEMPT_FIELDS.contains(field)) {
                    throw invalid(at, "不支持的字段 " + field);
                }
            }
            String table = string(at, fields, "table", true, 64);
            string(at, fields, "reason", true, 255);
            if (!SQL_IDENTIFIER.matcher(table).matches()) {
                throw invalid(at, "表名只能是小写字母、数字和下划线，且以字母开头：" + table);
            }
            if (controlledTables.contains(table)) {
                throw invalid(at, "表 " + table + " 已声明为受控资源，不能同时豁免");
            }
            if (!seen.add(table)) {
                throw invalid(at, "豁免表重复：" + table);
            }
        }
    }

    /** 解析一个文件的顶层列表。 */
    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> list(Map<String, String> files, String name) {
        Object document = loadYaml(files, name);
        if (document == null) {
            return List.of();
        }
        if (!(document instanceof List<?> rows)) {
            throw invalid(name, "顶层必须是列表");
        }
        List<Map<String, Object>> result = new ArrayList<>();
        for (int index = 0; index < rows.size(); index++) {
            if (!(rows.get(index) instanceof Map<?, ?> row)) {
                throw invalid(name + "#" + (index + 1), "每一项必须是对象");
            }
            result.add((Map<String, Object>) row);
        }
        return result;
    }

    /** 解析字典类型。 */
    @SuppressWarnings("unchecked")
    private static ProjectManifest.DictType dict(String at, Map<String, Object> row) {
        String code = code(at, row, "dictCode");
        ProjectManifest.Text name = text(at, row.get("name"), "name", 128);
        Object rawItems = row.get("items");
        if (!(rawItems instanceof List<?> items) || items.isEmpty()) {
            throw invalid(at, "字典 " + code + " 至少需要一个字典项");
        }
        List<ProjectManifest.DictItem> parsed = new ArrayList<>();
        Set<String> values = new HashSet<>();
        for (int index = 0; index < items.size(); index++) {
            String itemAt = at + ".items#" + (index + 1);
            if (!(items.get(index) instanceof Map<?, ?> item)) {
                throw invalid(itemAt, "字典项必须是对象");
            }
            Map<String, Object> map = (Map<String, Object>) item;
            String value = string(itemAt, map, "value", true, 128);
            if (!values.add(value)) {
                throw invalid(itemAt, "字典值重复：" + value);
            }
            parsed.add(new ProjectManifest.DictItem(
                    value,
                    text(itemAt, map.get("label"), "label", 128),
                    string(itemAt, map, "color", false, 32),
                    integer(itemAt, map, "sort", (index + 1) * 10),
                    bool(map, "default")));
        }
        return new ProjectManifest.DictType(
                code, name, string(at, row, "description", false, 512), List.copyOf(parsed));
    }

    /** 解析定时任务；Cron、时区与参数在这里就校验，避免执行时才发现。 */
    private static ProjectManifest.Job job(String at, Map<String, Object> row) {
        String cron = string(at, row, "cron", true, 128);
        try {
            CronExpression.parse(cron);
        } catch (RuntimeException exception) {
            throw invalid(at, "cron 表达式不合法：" + cron);
        }
        String zone = string(at, row, "zoneId", true, 64);
        try {
            ZoneId.of(zone);
        } catch (RuntimeException exception) {
            throw invalid(at, "zoneId 不合法：" + zone);
        }
        String payload = string(at, row, "payload", false, MAX_JOB_PAYLOAD);
        if (payload != null) {
            try {
                if (!JSON.readTree(payload).isObject()) {
                    throw invalid(at, "payload 必须是 JSON 对象");
                }
            } catch (ApiException exception) {
                throw exception;
            } catch (RuntimeException exception) {
                throw invalid(at, "payload 必须是合法的 JSON 对象文本");
            }
        }
        return new ProjectManifest.Job(
                string(at, row, "jobName", true, 128),
                string(at, row, "taskType", true, 128),
                cron,
                zone,
                payload,
                bool(row, "enabled"));
    }

    /** 解析项目国际化资源：messageKey、zh-CN 默认文本，其余键视为语言代码。 */
    private static ProjectManifest.Message message(String at, Map<String, Object> row) {
        String key = string(at, row, "messageKey", true, 160);
        if (!MESSAGE_KEY.matcher(key).matches()) {
            throw invalid(at, "messageKey 格式不正确：" + key);
        }
        Object zh = row.get("zh-CN");
        if (!(zh instanceof String defaultText) || defaultText.isBlank()) {
            throw invalid(at, "国际化资源 " + key + " 必须提供 zh-CN 文本");
        }
        Map<String, String> translations = new LinkedHashMap<>();
        for (Map.Entry<?, ?> entry : row.entrySet()) {
            String locale = String.valueOf(entry.getKey());
            if ("messageKey".equals(locale) || "description".equals(locale) || "zh-CN".equals(locale)) {
                continue;
            }
            if (!LOCALE.matcher(locale).matches() || !(entry.getValue() instanceof String translated)) {
                throw invalid(at, "语言代码或译文不合法：" + locale);
            }
            translations.put(locale, limit(at, locale, translated.trim(), MAX_MESSAGE_TEXT));
        }
        return new ProjectManifest.Message(
                key,
                limit(at, "zh-CN", defaultText.trim(), MAX_MESSAGE_TEXT),
                Map.copyOf(translations),
                string(at, row, "description", false, 255));
    }

    /** 解析自定义角色及授权；内置 project-admin 不能出现在清单里。 */
    private static ProjectManifest.Role role(String at, Map<String, Object> row) {
        String code = string(at, row, "roleCode", true, 64);
        if (!ROLE_CODE.matcher(code).matches()) {
            throw invalid(at, "roleCode 只能包含小写字母、数字和连字符：" + code);
        }
        if ("project-admin".equals(code)) {
            throw invalid(at, "内置角色 project-admin 不由移交包管理");
        }
        List<String> directories = grants(at, row, "directories", 255);
        for (String directory : directories) {
            if (!directory.startsWith("dir:")) {
                throw invalid(at, "directories 的值必须以 dir: 开头：" + directory);
            }
        }
        return new ProjectManifest.Role(
                code,
                string(at, row, "name", true, 100),
                string(at, row, "description", false, 255),
                grants(at, row, "permissions", 128),
                grants(at, row, "routes", 255),
                directories,
                roleDataScopes(at, row.get("dataScopes")));
    }

    /**
     * 解析角色的 {@code dataScopes}（docs/DATA_SCOPE.md §7）。
     *
     * <p>部门用部门编码表示，因为部门 ID 在各环境不同。同一资源在一个角色内只能出现一次；
     * 部门只能配合 {@code CUSTOM_DEPT}，且该类型必须至少有一个部门。</p>
     */
    private static List<ProjectManifest.RoleDataScope> roleDataScopes(String at, Object raw) {
        if (raw == null) {
            return List.of();
        }
        if (!(raw instanceof List<?> rows)) {
            throw invalid(at, "dataScopes 必须是列表");
        }
        List<ProjectManifest.RoleDataScope> result = new ArrayList<>();
        Set<String> resources = new HashSet<>();
        for (int index = 0; index < rows.size(); index++) {
            String item = at + ".dataScopes" + (index + 1);
            if (!(rows.get(index) instanceof Map<?, ?> row)) {
                throw invalid(item, "每一项必须是对象");
            }
            Map<String, Object> fields = (Map<String, Object>) row;
            for (String field : fields.keySet()) {
                if (!ROLE_DATA_SCOPE_FIELDS.contains(field)) {
                    throw invalid(item, "不支持的字段 " + field);
                }
            }
            String resource = string(item, fields, "resource", true, 128);
            if (!DATA_RESOURCE_CODE.matcher(resource).matches()) {
                throw invalid(item, "resource 格式应为 模块:资源：" + resource);
            }
            if (!resources.add(resource)) {
                throw invalid(item, "同一角色内资源重复：" + resource);
            }
            String scopeName = string(item, fields, "scope", true, 32);
            DataScopeType scope =
                    DataScopeType.parse(scopeName).orElseThrow(() -> invalid(item, "scope 取值无效：" + scopeName));
            Object rawIncludeChild = fields.get("includeChild");
            if (rawIncludeChild != null && !(rawIncludeChild instanceof Boolean)) {
                throw invalid(item, "includeChild 必须是 true 或 false");
            }
            boolean includeChild = Boolean.TRUE.equals(rawIncludeChild);
            List<String> depts = grants(item, fields, "depts", 64);
            if (scope != DataScopeType.CUSTOM_DEPT && (!depts.isEmpty() || includeChild)) {
                throw invalid(item, "只有 CUSTOM_DEPT 可以指定 depts 或 includeChild");
            }
            if (scope == DataScopeType.CUSTOM_DEPT && depts.isEmpty()) {
                throw invalid(item, "CUSTOM_DEPT 至少需要一个部门编码");
            }
            if (depts.size() > MAX_ROLE_SCOPE_DEPARTMENTS) {
                throw invalid(item, "depts 最多 " + MAX_ROLE_SCOPE_DEPARTMENTS + " 项");
            }
            result.add(new ProjectManifest.RoleDataScope(resource, scope.name(), includeChild, depts));
        }
        return List.copyOf(result);
    }

    /** 读取授权键列表，去重并限制数量与长度。 */
    private static List<String> grants(String at, Map<String, Object> row, String field, int maxLength) {
        Object raw = row.get(field);
        if (raw == null) {
            return List.of();
        }
        if (!(raw instanceof List<?> values)) {
            throw invalid(at, field + " 必须是列表");
        }
        if (values.size() > MAX_GRANTS) {
            throw invalid(at, field + " 最多 " + MAX_GRANTS + " 项");
        }
        Set<String> result = new LinkedHashSet<>();
        for (Object value : values) {
            if (!(value instanceof String text) || text.isBlank()) {
                throw invalid(at, field + " 的每一项必须是非空文本");
            }
            result.add(limit(at, field, text.trim(), maxLength));
        }
        return List.copyOf(result);
    }

    /** 解析参数配置；敏感项一律拒绝，密钥不得进入仓库。 */
    private static ProjectManifest.Config config(String at, Map<String, Object> row) {
        String key = code(at, row, "key");
        if (bool(row, "secret") || SENSITIVE_KEY.matcher(key).matches()) {
            throw invalid(at, "清单禁止声明敏感配置：" + key + "；密钥类继续走环境变量或平台加密配置");
        }
        String type = string(at, row, "type", false, 16);
        type = type == null ? "STRING" : type;
        if (!VALUE_TYPE.matcher(type).matches()) {
            throw invalid(at, "配置类型只能是 STRING、NUMBER、BOOLEAN、JSON");
        }
        Object raw = row.get("default");
        String defaultValue = raw == null ? null : String.valueOf(raw);
        return new ProjectManifest.Config(key, type, defaultValue, string(at, row, "description", false, 512));
    }

    /** 递归解析菜单节点，权限码在整份清单内唯一。 */
    @SuppressWarnings("unchecked")
    private static ProjectManifest.Menu menu(String at, Map<String, Object> row, Set<String> permissions) {
        String type = string(at, row, "type", true, 16);
        if (!MENU_TYPE.matcher(type).matches()) {
            throw invalid(at, "菜单类型只能是 DIRECTORY、MENU、BUTTON");
        }
        String path = string(at, row, "path", false, 255);
        String permission = string(at, row, "permission", false, 128);
        if ("MENU".equals(type) && path == null) {
            throw invalid(at, "MENU 节点必须有 path");
        }
        if ("BUTTON".equals(type)) {
            if (permission == null) {
                throw invalid(at, "BUTTON 节点必须有 permission");
            }
            if (!permissions.add(permission)) {
                throw invalid(at, "权限码重复：" + permission);
            }
        }
        List<ProjectManifest.Menu> children = new ArrayList<>();
        if (row.get("children") instanceof List<?> rawChildren) {
            if ("BUTTON".equals(type) && !rawChildren.isEmpty()) {
                throw invalid(at, "BUTTON 节点不能有子节点");
            }
            for (int index = 0; index < rawChildren.size(); index++) {
                if (!(rawChildren.get(index) instanceof Map<?, ?> child)) {
                    throw invalid(at + ".children#" + (index + 1), "子节点必须是对象");
                }
                children.add(menu(at + ".children#" + (index + 1), (Map<String, Object>) child, permissions));
            }
        }
        Object rawName = row.get("name");
        ProjectManifest.Text name = rawName == null && permission != null
                ? new ProjectManifest.Text(permission, Map.of())
                : text(at, rawName, "name", 64);
        return new ProjectManifest.Menu(
                type,
                name,
                path,
                string(at, row, "component", false, 255),
                permission,
                string(at, row, "icon", false, 64),
                integer(at, row, "sort", 0),
                List.copyOf(children));
    }

    /** 文本既可写成字符串（只有 zh-CN），也可写成 {zh-CN: .., en-US: .., i18nKey: ..}。 */
    private static ProjectManifest.Text text(String at, Object raw, String field, int maxLength) {
        if (raw instanceof String value && !value.isBlank()) {
            return new ProjectManifest.Text(limit(at, field, value.trim(), maxLength), Map.of());
        }
        if (raw instanceof Map<?, ?> map) {
            Object zh = map.get("zh-CN");
            if (!(zh instanceof String defaultText) || defaultText.isBlank()) {
                throw invalid(at, field + " 必须提供 zh-CN 文本");
            }
            Map<String, String> translations = new LinkedHashMap<>();
            String explicitKey = null;
            for (Map.Entry<?, ?> entry : map.entrySet()) {
                String locale = String.valueOf(entry.getKey());
                if ("zh-CN".equals(locale)) {
                    continue;
                }
                if (I18N_KEY_FIELD.equals(locale)) {
                    if (!(entry.getValue() instanceof String rawKey)
                            || !CODE.matcher(rawKey.trim()).matches()) {
                        throw invalid(at, field + " 的 i18nKey 格式不正确");
                    }
                    explicitKey = limit(at, field, rawKey.trim(), 160);
                    continue;
                }
                if (!LOCALE.matcher(locale).matches() || !(entry.getValue() instanceof String translated)) {
                    throw invalid(at, field + " 的语言代码或译文不合法：" + locale);
                }
                translations.put(locale, limit(at, field, translated.trim(), maxLength));
            }
            return new ProjectManifest.Text(
                    limit(at, field, defaultText.trim(), maxLength), Map.copyOf(translations), explicitKey);
        }
        throw invalid(at, "缺少 " + field);
    }

    /** 读取并校验编码类字段。 */
    private static String code(String at, Map<String, Object> row, String field) {
        String value = string(at, row, field, true, 128);
        if (!CODE.matcher(value).matches()) {
            throw invalid(at, field + " 格式不正确：" + value);
        }
        return value;
    }

    /** 读取字符串字段；数字等标量按字符串处理。 */
    private static String string(String at, Map<String, Object> row, String field, boolean required, int maxLength) {
        Object raw = row.get(field);
        if (raw == null || (raw instanceof String text && text.isBlank())) {
            if (required) {
                throw invalid(at, "缺少 " + field);
            }
            return null;
        }
        if (raw instanceof Map<?, ?> || raw instanceof List<?>) {
            throw invalid(at, field + " 必须是文本");
        }
        return limit(at, field, String.valueOf(raw).trim(), maxLength);
    }

    /** 读取整数字段。 */
    private static int integer(String at, Map<String, Object> row, String field, int fallback) {
        Object raw = row.get(field);
        if (raw == null) {
            return fallback;
        }
        if (!(raw instanceof Integer value) || value < 0 || value > 9999) {
            throw invalid(at, field + " 必须是 0-9999 的整数");
        }
        return value;
    }

    /** 读取布尔字段，缺省为 false。 */
    private static boolean bool(Map<String, Object> row, String field) {
        return Boolean.TRUE.equals(row.get(field));
    }

    /** 长度校验。 */
    private static String limit(String at, String field, String value, int maxLength) {
        if (value.length() > maxLength) {
            throw invalid(at, field + " 不能超过 " + maxLength + " 个字符");
        }
        return value;
    }

    /** 取异常消息第一行，避免把整段 YAML 回显给调用方。 */
    private static String firstLine(String message) {
        if (message == null) {
            return "";
        }
        int newline = message.indexOf('\n');
        return newline < 0 ? message : message.substring(0, newline);
    }

    /** 统一的清单校验错误。 */
    private static ApiException invalid(String at, String reason) {
        return new ApiException(HttpStatus.BAD_REQUEST, "清单 " + at + "：" + reason, "api.common.badRequest");
    }
}
