package com.kaiwu.module.factory.model;

import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 业务项目声明的平台资源清单（ADR 0036）。
 *
 * <p>只描述"应当存在"的资源，不表达删除；平台上多出的条目在计划里列为漂移。</p>
 *
 * @param dataResources 受控数据资源（ADR 0044），来自 {@code data-scopes.yml}；只声明哪张表按哪两列判断归属，
 *                      不含任何范围授权
 */
public record ProjectManifest(
        List<DictType> dicts,
        List<Config> configs,
        List<Menu> menus,
        List<Role> roles,
        List<Job> jobs,
        List<Message> messages,
        List<DataResource> dataResources) {

    /** 建项目时由平台种入的菜单路由；目标项目创建时已有，不随移交包导出，也不计入漂移。 */
    public static final Set<String> SEEDED_MENU_ROUTES = Set.of("/project-members", "/project-roles", "/project-files");

    /** 不含角色的清单，业务仓 {@code kaiwu/} 目录的三个文件只有这些。 */
    public ProjectManifest(List<DictType> dicts, List<Config> configs, List<Menu> menus) {
        this(dicts, configs, menus, List.of(), List.of(), List.of(), List.of());
    }

    /** 含角色、不含定时任务与国际化资源的清单。 */
    public ProjectManifest(List<DictType> dicts, List<Config> configs, List<Menu> menus, List<Role> roles) {
        this(dicts, configs, menus, roles, List.of(), List.of(), List.of());
    }

    /** 不含受控数据资源的清单（ADR 0044 之前的六类内容）。 */
    public ProjectManifest(
            List<DictType> dicts,
            List<Config> configs,
            List<Menu> menus,
            List<Role> roles,
            List<Job> jobs,
            List<Message> messages) {
        this(dicts, configs, menus, roles, jobs, messages, List.of());
    }

    /**
     * 多语言文本：zh-CN 作为默认文本，其余语言写入引用式国际化资源（ADR 0015）。
     *
     * @param defaultText  zh-CN 文本
     * @param translations 其余语言到译文；为空表示只有默认语言，不创建国际化资源
     * @param messageKey   显式指定的国际化资源 key（ADR 0042）；为空时由平台按规则生成
     */
    public record Text(String defaultText, Map<String, String> translations, String messageKey) {

        /** 不指定 key 的文本，沿用 ADR 0036 的生成规则。 */
        public Text(String defaultText, Map<String, String> translations) {
            this(defaultText, translations, null);
        }

        /** 是否需要引用式国际化资源。 */
        public boolean translated() {
            return translations != null && !translations.isEmpty();
        }
    }

    /** 字典类型及其字典项。 */
    public record DictType(String dictCode, Text name, String description, List<DictItem> items) {}

    /** 字典项；颜色与排序归清单所有。 */
    public record DictItem(String value, Text label, String color, int sort, boolean defaultItem) {}

    /**
     * 参数配置。
     *
     * @param defaultValue 只在首次创建时写入；之后的当前值归平台运营
     */
    public record Config(String key, String valueType, String defaultValue, String description) {}

    /**
     * 菜单节点。
     *
     * <p>匹配平台已有节点的依据：BUTTON 用权限码，MENU 用路由，DIRECTORY 用同一父节点下的名称。</p>
     */
    public record Menu(
            String menuType,
            Text name,
            String path,
            String component,
            String permission,
            String icon,
            int sort,
            List<Menu> children) {}

    /**
     * 自定义角色及其授权（ADR 0042）；授权用业务键表示，不含数据库 ID。
     *
     * <p>只追加授权，不撤销目标环境已有的授权；角色名称与说明只在新建时使用。</p>
     *
     * @param roleCode    角色编码，不能是内置的 project-admin
     * @param roleName    角色名称
     * @param description 角色说明，可空
     * @param permissions 按钮权限码
     * @param routes      页面路由
     * @param directories 目录，写作 {@code dir:} 加名称路径
     * @param dataScopes  数据范围（ADR 0044），按资源给出；没有配置的资源不出现，等价于仅本人
     */
    public record Role(
            String roleCode,
            String roleName,
            String description,
            List<String> permissions,
            List<String> routes,
            List<String> directories,
            List<RoleDataScope> dataScopes) {

        /** 不含数据范围的角色（ADR 0044 之前的格式）。 */
        public Role(
                String roleCode,
                String roleName,
                String description,
                List<String> permissions,
                List<String> routes,
                List<String> directories) {
            this(roleCode, roleName, description, permissions, routes, directories, List.of());
        }
    }

    /**
     * 角色在某受控资源上的数据范围（docs/DATA_SCOPE.md §7）。
     *
     * @param resource     资源码
     * @param scope        范围类型名称
     * @param includeChild 仅 {@code CUSTOM_DEPT} 有意义
     * @param depts        仅 {@code CUSTOM_DEPT} 使用的部门<b>编码</b>，不是 ID
     */
    public record RoleDataScope(String resource, String scope, boolean includeChild, List<String> depts) {}

    /**
     * 定时任务配置（ADR 0042）。业务键是任务名。
     *
     * <p>在目标环境新建时一律停用，已有任务只更新 cron、时区、任务类型与参数，不改启用状态：
     * 启用要求目标项目已有在线 Handler，这取决于目标环境里业务服务是否在运行。</p>
     *
     * @param jobName        任务名，项目内唯一
     * @param taskType       任务类型，对应业务服务注册的 Handler
     * @param cronExpression Cron 表达式
     * @param zoneId         时区
     * @param payload        任务参数，JSON 对象文本，可空
     * @param enabled        导出时的启用状态，仅供参考，导入不使用
     */
    public record Job(
            String jobName, String taskType, String cronExpression, String zoneId, String payload, boolean enabled) {}

    /**
     * 项目国际化资源（ADR 0037、ADR 0042）。业务键是资源 key。
     *
     * <p>目标环境已存在而文案不同时，按移交包更新。</p>
     *
     * @param messageKey   资源 key
     * @param defaultText  zh-CN 文本
     * @param translations 其余语言到译文，可空
     * @param description  说明，可空
     */
    public record Message(
            String messageKey, String defaultText, Map<String, String> translations, String description) {}

    /**
     * 受控数据资源声明（docs/DATA_SCOPE.md §2）。表名与归属列只供业务服务运行时使用，平台只保存资源码、展示名与允许范围。
     *
     * @param code            资源码，约定同权限前缀
     * @param name            管理端展示名
     * @param table           业务表名
     * @param ownerUserColumn 归属人列
     * @param ownerDeptColumn 归属部门列
     * @param allowedScopes   允许选择的范围类型，已按枚举顺序去重，必含 {@code SELF}
     */
    public record DataResource(
            String code,
            String name,
            String table,
            String ownerUserColumn,
            String ownerDeptColumn,
            List<String> allowedScopes) {}
}
