package com.kaiwu.module.agent.catalog;

import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.DataScope;
import com.kaiwu.module.agent.protocol.ParamSpec;
import com.kaiwu.module.agent.protocol.ParamType;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.springframework.stereotype.Component;

/**
 * 聚合控制面本地能力与已审核在线的业务查询。远程能力按实时项目权限裁剪，
 * 不能用平台权限代替；默认开关关闭时仍保留经平台审核的本地能力。
 */
@Component
public class CapabilityCatalog {

    public static final String PROJECT_CREATE = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_CREATE;
    public static final String PROJECT_STATUS_UPDATE = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_STATUS_UPDATE;
    public static final String PROJECT_RENAME = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_RENAME;
    public static final String PROJECT_ROLE_CREATE = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_ROLE_CREATE;
    public static final String PROJECT_ROLE_UPDATE = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_ROLE_UPDATE;
    public static final String PROJECT_ROLE_DELETE = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_ROLE_DELETE;
    public static final String PROJECT_ROLE_STATUS_UPDATE =
            com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_ROLE_STATUS_UPDATE;
    public static final String PROJECT_ROLE_MENU_GRANT =
            com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_ROLE_MENU_GRANT;
    public static final String PROJECT_MENU_STATUS_UPDATE =
            com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_MENU_STATUS_UPDATE;
    public static final String PROJECT_MENU_DELETE = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_MENU_DELETE;
    public static final String PROJECT_MENU_CREATE = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_MENU_CREATE;
    public static final String PROJECT_MENU_UPDATE = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_MENU_UPDATE;
    public static final String DICT_TYPE_CREATE = com.kaiwu.port.agent.AgentCapabilityCodes.DICT_TYPE_CREATE;
    public static final String DICT_ITEM_CREATE = com.kaiwu.port.agent.AgentCapabilityCodes.DICT_ITEM_CREATE;
    public static final String DICT_TYPE_RENAME = com.kaiwu.port.agent.AgentCapabilityCodes.DICT_TYPE_RENAME;
    public static final String DICT_TYPE_DELETE = com.kaiwu.port.agent.AgentCapabilityCodes.DICT_TYPE_DELETE;
    public static final String DICT_ITEM_RENAME = com.kaiwu.port.agent.AgentCapabilityCodes.DICT_ITEM_RENAME;
    public static final String DICT_ITEM_DELETE = com.kaiwu.port.agent.AgentCapabilityCodes.DICT_ITEM_DELETE;
    public static final String CONFIG_CREATE = com.kaiwu.port.agent.AgentCapabilityCodes.CONFIG_CREATE;
    public static final String CONFIG_DELETE = com.kaiwu.port.agent.AgentCapabilityCodes.CONFIG_DELETE;
    public static final String PROJECT_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_LIST;
    public static final String PROJECT_DETAIL = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_DETAIL;
    public static final String GENERATION_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.GENERATION_LIST;
    public static final String SCHEDULER_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.SCHEDULER_LIST;
    public static final String SCHEDULER_EXECUTION_LIST =
            com.kaiwu.port.agent.AgentCapabilityCodes.SCHEDULER_EXECUTION_LIST;
    public static final String USER_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.USER_LIST;
    public static final String USER_CREATE = com.kaiwu.port.agent.AgentCapabilityCodes.USER_CREATE;
    public static final String USER_DISPLAY_NAME_UPDATE =
            com.kaiwu.port.agent.AgentCapabilityCodes.USER_DISPLAY_NAME_UPDATE;
    public static final String USER_PROFILE_UPDATE = com.kaiwu.port.agent.AgentCapabilityCodes.USER_PROFILE_UPDATE;
    public static final String USER_PASSWORD_RESET = com.kaiwu.port.agent.AgentCapabilityCodes.USER_PASSWORD_RESET;
    public static final String USER_STATUS_UPDATE = com.kaiwu.port.agent.AgentCapabilityCodes.USER_STATUS_UPDATE;
    public static final String DEPARTMENT_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.DEPARTMENT_LIST;
    public static final String DEPARTMENT_CREATE = com.kaiwu.port.agent.AgentCapabilityCodes.DEPARTMENT_CREATE;
    public static final String DEPARTMENT_RENAME = com.kaiwu.port.agent.AgentCapabilityCodes.DEPARTMENT_RENAME;
    public static final String DEPARTMENT_STATUS_UPDATE =
            com.kaiwu.port.agent.AgentCapabilityCodes.DEPARTMENT_STATUS_UPDATE;
    public static final String DEPARTMENT_DELETE = com.kaiwu.port.agent.AgentCapabilityCodes.DEPARTMENT_DELETE;
    public static final String USER_DEPARTMENT_ASSIGN =
            com.kaiwu.port.agent.AgentCapabilityCodes.USER_DEPARTMENT_ASSIGN;
    public static final String CONFIG_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.CONFIG_LIST;
    public static final String CONFIG_DETAIL = com.kaiwu.port.agent.AgentCapabilityCodes.CONFIG_DETAIL;
    public static final String DICT_TYPE_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.DICT_TYPE_LIST;
    public static final String DICT_ITEM_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.DICT_ITEM_LIST;
    public static final String PROJECT_MEMBER_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_MEMBER_LIST;
    public static final String PROJECT_MEMBER_SAVE = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_MEMBER_SAVE;
    public static final String PROJECT_MEMBER_DELETE = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_MEMBER_DELETE;
    public static final String PROJECT_ROLE_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_ROLE_LIST;
    public static final String OPERATION_LOG_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.OPERATION_LOG_LIST;
    public static final String LOGIN_LOG_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.LOGIN_LOG_LIST;
    public static final String SESSION_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.SESSION_LIST;
    public static final String AI_PROVIDER_STATUS = com.kaiwu.port.agent.AgentCapabilityCodes.AI_PROVIDER_STATUS;
    public static final String I18N_MESSAGE_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.I18N_MESSAGE_LIST;
    public static final String I18N_LOCALE_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.I18N_LOCALE_LIST;
    public static final String PROJECT_MENU_LIST = com.kaiwu.port.agent.AgentCapabilityCodes.PROJECT_MENU_LIST;
    public static final String GENERATION_DETAIL = com.kaiwu.port.agent.AgentCapabilityCodes.GENERATION_DETAIL;

    private final Map<String, Capability> capabilities;
    private RemoteCapabilitySource remote;

    public CapabilityCatalog() {
        this.capabilities = declare();
    }

    @org.springframework.beans.factory.annotation.Autowired
    public void remoteSource(RemoteCapabilitySource source) {
        this.remote = source;
    }

    private static Map<String, Capability> declare() {
        // dataScope=ALL 是如实声明而非放宽：ProjectController.page 只校验
        // system:project:list 这一平台级权限，不做成员关系收窄，持有者通过 UI
        // 本来就能看到全部项目。Agent 不应比 UI 更严或更松，否则用户无法预期。
        Capability projectList = Capability.builder(PROJECT_LIST)
                .description("查询平台全部项目及其状态，需要平台级项目查看权限")
                .permission("system:project:list")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "keyword", ParamSpec.optionalString(64),
                        "status", ParamSpec.optionalEnum(Set.of("ACTIVE", "DISABLED")),
                        "pageSize", ParamSpec.pageSize(50, 20)))
                // backendUrl 只随浏览器卡片返回，用于判断入口；不加入 outboundFields，避免把地址送入模型。
                .outboundFields("id", "projectCode", "projectName", "status")
                .verifiedReadOnly()
                .build();
        Capability projectDetail = Capability.builder(PROJECT_DETAIL)
                .description("按项目 ID 查询平台项目详情、状态和基础元数据；不返回仓库、服务或内部路由地址")
                .permission("system:project:list")
                .dataScope(DataScope.ALL)
                .params(Map.of("projectId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null)))
                .outboundFields(
                        "id", "projectCode", "projectName", "description", "status", "packageName", "defaultBranch")
                .verifiedReadOnly()
                .build();

        // dataScope=SELF：ProjectGenerationService.list 的注释写明是「当前用户发起过的
        // 生成任务」，按 ownerUserId 过滤。描述必须如实说「我发起的」——若写成
        // 「哪些项目生成失败」，模型会据此给出以偏概全的答复。
        Capability generationList = Capability.builder(GENERATION_LIST)
                .description("查询我发起的项目生成任务及其状态，可按项目或状态过滤")
                .permission("system:project-factory:list")
                .dataScope(DataScope.SELF)
                .params(Map.of(
                        "projectId", ParamSpec.optionalVisibleProject(),
                        "status", ParamSpec.optionalEnum(Set.of("PENDING", "RUNNING", "SUCCESS", "FAILED")),
                        "pageSize", ParamSpec.pageSize(50, 20)))
                .outboundFields("taskNo", "projectCode", "projectName", "status", "generationMode")
                .verifiedReadOnly()
                .build();
        Capability generationDetail = Capability.builder(GENERATION_DETAIL)
                .description("查询我发起的指定项目生成任务状态、版本和时间；不返回生成输入、文件清单、仓库地址或错误原文")
                .permission("system:project-factory:list")
                .dataScope(DataScope.SELF)
                .params(Map.of("taskNo", new ParamSpec(ParamType.STRING, true, null, null, 64, null, null, null)))
                .outboundFields(
                        "taskNo",
                        "projectCode",
                        "projectName",
                        "generationMode",
                        "status",
                        "templateVersion",
                        "startedAt",
                        "completedAt")
                .verifiedReadOnly()
                .build();

        // dataScope=MEMBER_PROJECTS：ProjectSchedulerService.jobs 指定项目时
        // requireMember，不指定时 jobsForUser 按成员关系收窄。
        Capability schedulerList = Capability.builder(SCHEDULER_LIST)
                .description("查询我参与项目的定时任务及其最近执行状态，可按项目或启停状态过滤")
                .permission("system:scheduler:list")
                .dataScope(DataScope.MEMBER_PROJECTS)
                .params(Map.of(
                        "projectId", ParamSpec.optionalVisibleProject(),
                        "enabled", ParamSpec.optionalBool(),
                        "pageSize", ParamSpec.pageSize(50, 20)))
                .outboundFields("id", "jobName", "projectName", "taskType", "enabled", "lastRunTime")
                .verifiedReadOnly()
                .build();

        Capability projectCreate = Capability.builder(PROJECT_CREATE)
                .description("创建平台项目，仅生成待确认预览；必须提供项目编码和名称，用户点击确认后才执行")
                .permission("system:project:create")
                .dataScope(DataScope.SELF)
                .params(Map.of(
                        "projectCode",
                        new ParamSpec(ParamType.STRING, true, null, null, 64, null, null, null),
                        "projectName",
                        new ParamSpec(ParamType.STRING, true, null, null, 100, null, null, null),
                        "description",
                        ParamSpec.optionalString(500),
                        "packageName",
                        ParamSpec.optionalString(128)))
                .inputForm(
                        "agent.input.title",
                        List.of("projectCode", "projectName", "packageName", "description"),
                        Set.of("description"),
                        Map.of("projectCode", "slug", "packageName", "javaPackage"))
                .outboundFields("id", "projectCode", "projectName")
                .build();
        Capability projectStatusUpdate = Capability.builder(PROJECT_STATUS_UPDATE)
                .description("启用、停用或归档平台项目；必须先确认项目 ID 与当前名称状态，停用和归档要求强确认；内置 system 项目不可修改")
                .permission("system:project:status")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "status",
                                new ParamSpec(
                                        ParamType.ENUM,
                                        true,
                                        null,
                                        null,
                                        null,
                                        Set.of("ACTIVE", "DISABLED", "ARCHIVED"),
                                        null,
                                        null)))
                .inputForm(
                        "agent.input.projectStatusUpdateTitle",
                        List.of("projectId", "status"),
                        Set.of(),
                        Map.of(),
                        Map.of("status", "project.status"))
                .outboundFields("id", "projectCode", "projectName", "status")
                .build();
        Capability projectRename = Capability.builder(PROJECT_RENAME)
                .description("修改平台项目名称；项目编码及仓库、服务和路由设置保持不变，先核对项目 ID 和当前名称再确认")
                .permission("system:project:update")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "projectName", new ParamSpec(ParamType.STRING, true, null, null, 100, null, null, null)))
                .inputForm("agent.input.projectRenameTitle", List.of("projectId", "projectName"), Set.of(), Map.of())
                .outboundFields("id", "projectCode", "projectName")
                .build();
        Capability projectRoleCreate = Capability.builder(PROJECT_ROLE_CREATE)
                .description("为指定平台项目创建自定义角色；填写项目 ID、角色编码和名称，预览项目后确认")
                .permission("system:project:role")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "newRoleCode", new ParamSpec(ParamType.STRING, true, null, null, 64, null, null, null),
                        "roleName", new ParamSpec(ParamType.STRING, true, null, null, 100, null, null, null),
                        "description", ParamSpec.optionalString(255)))
                .inputForm(
                        "agent.input.projectRoleCreateTitle",
                        List.of("projectId", "newRoleCode", "roleName", "description"),
                        Set.of("description"),
                        Map.of("newRoleCode", "slug"))
                .outboundFields("id", "projectId", "roleCode", "roleName")
                .build();
        Capability projectRoleUpdate = Capability.builder(PROJECT_ROLE_UPDATE)
                .description("修改指定项目自定义角色的名称或描述；预览显示当前角色信息，确认时若角色已变化则拒绝")
                .permission("system:project:role")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId",
                        new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "targetRoleId",
                        new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "roleName",
                        ParamSpec.optionalString(100),
                        "description",
                        ParamSpec.optionalString(255)))
                .inputForm(
                        "agent.input.projectRoleUpdateTitle",
                        List.of("projectId", "targetRoleId", "roleName", "description"),
                        Set.of("roleName", "description"),
                        Map.of())
                .outboundFields("id", "projectId", "roleCode", "roleName", "description", "status")
                .build();
        Capability projectRoleDelete = Capability.builder(PROJECT_ROLE_DELETE)
                .description("删除没有成员使用的自定义项目角色；必须核对项目和角色信息，输入确认短语后才执行")
                .permission("system:project:role")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "targetRoleId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null)))
                .inputForm(
                        "agent.input.projectRoleDeleteTitle", List.of("projectId", "targetRoleId"), Set.of(), Map.of())
                .outboundFields("id", "projectId", "roleCode", "roleName", "status")
                .build();
        Capability projectRoleStatusUpdate = Capability.builder(PROJECT_ROLE_STATUS_UPDATE)
                .description("启用或停用自定义项目角色；停用会影响成员权限，须输入强确认短语")
                .permission("system:project:role")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "targetRoleId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "status",
                                new ParamSpec(
                                        ParamType.ENUM,
                                        true,
                                        null,
                                        null,
                                        null,
                                        Set.of("ACTIVE", "DISABLED"),
                                        null,
                                        null)))
                .inputForm(
                        "agent.input.projectRoleStatusTitle",
                        List.of("projectId", "targetRoleId", "status"),
                        Set.of(),
                        Map.of(),
                        Map.of("status", "project.member.status"))
                .outboundFields("id", "projectId", "roleCode", "roleName", "status")
                .build();
        Capability projectRoleMenuGrant = Capability.builder(PROJECT_ROLE_MENU_GRANT)
                .description("全量替换自定义项目角色的菜单授权；输入目标项目、角色和最多 100 个菜单编号，清空授权需强确认")
                .permission("system:project:role")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "targetRoleId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "menuIds", ParamSpec.stringList(true, 0, 100, 19)))
                .inputForm(
                        "agent.input.projectRoleMenuGrantTitle",
                        List.of("projectId", "targetRoleId", "menuIds"),
                        Set.of(),
                        Map.of())
                .outboundFields("id", "projectId", "roleCode", "roleName", "menuIds")
                .build();
        Capability projectMenuStatusUpdate = Capability.builder(PROJECT_MENU_STATUS_UPDATE)
                .description("启用或停用指定项目菜单；停用会撤销相关权限，需输入强确认短语")
                .permission("system:project:menu")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "targetMenuId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "status",
                                new ParamSpec(
                                        ParamType.ENUM,
                                        true,
                                        null,
                                        null,
                                        null,
                                        Set.of("ACTIVE", "DISABLED"),
                                        null,
                                        null)))
                .inputForm(
                        "agent.input.projectMenuStatusTitle",
                        List.of("projectId", "targetMenuId", "status"),
                        Set.of(),
                        Map.of(),
                        Map.of("status", "project.member.status"))
                .outboundFields("id", "projectId", "menuName", "menuType", "status")
                .build();
        Capability projectMenuDelete = Capability.builder(PROJECT_MENU_DELETE)
                .description("删除指定项目的无子节点菜单；操作会撤销角色菜单关系，需输入强确认短语")
                .permission("system:project:menu")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "targetMenuId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null)))
                .inputForm(
                        "agent.input.projectMenuDeleteTitle", List.of("projectId", "targetMenuId"), Set.of(), Map.of())
                .outboundFields("id", "projectId", "menuName", "menuType", "status")
                .build();
        Map<String, ParamSpec> projectMenuFields = new java.util.LinkedHashMap<>();
        projectMenuFields.put("projectId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null));
        projectMenuFields.put("parentId", ParamSpec.optionalString(19));
        projectMenuFields.put("menuName", new ParamSpec(ParamType.STRING, true, null, null, 100, null, null, null));
        projectMenuFields.put("menuNameKey", ParamSpec.optionalString(160));
        projectMenuFields.put(
                "menuType",
                new ParamSpec(ParamType.ENUM, true, null, null, null, Set.of("DIR", "MENU", "BUTTON"), null, null));
        projectMenuFields.put("routePath", ParamSpec.optionalString(256));
        projectMenuFields.put("componentPath", ParamSpec.optionalString(256));
        projectMenuFields.put("permissionCode", ParamSpec.optionalString(128));
        projectMenuFields.put("icon", ParamSpec.optionalString(64));
        projectMenuFields.put("sortNo", new ParamSpec(ParamType.INT, false, 0, 9999, null, null, null, 0));
        projectMenuFields.put("visible", new ParamSpec(ParamType.BOOL, false, null, null, null, null, null, true));
        List<String> projectMenuFormFields = List.of(
                "projectId",
                "parentId",
                "menuName",
                "menuNameKey",
                "menuType",
                "routePath",
                "componentPath",
                "permissionCode",
                "icon",
                "sortNo",
                "visible");
        Set<String> optionalProjectMenuFields =
                Set.of("parentId", "menuNameKey", "routePath", "componentPath", "permissionCode", "icon");
        Capability projectMenuCreate = Capability.builder(PROJECT_MENU_CREATE)
                .description("在指定项目创建目录、页面或权限按钮；完整填写菜单信息，权限码和父菜单需属于该项目，强确认后生效")
                .permission("system:project:menu")
                .dataScope(DataScope.ALL)
                .params(Map.copyOf(projectMenuFields))
                .inputForm(
                        "agent.input.projectMenuCreateTitle",
                        projectMenuFormFields,
                        optionalProjectMenuFields,
                        Map.of(),
                        Map.of("menuType", "platform.menu.type"))
                .outboundFields("id", "projectId", "menuName", "menuType", "permissionCode")
                .build();
        Map<String, ParamSpec> projectMenuUpdateFields = new java.util.LinkedHashMap<>(projectMenuFields);
        projectMenuUpdateFields.put(
                "targetMenuId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null));
        List<String> projectMenuUpdateFormFields = new java.util.ArrayList<>(projectMenuFormFields);
        projectMenuUpdateFormFields.add(1, "targetMenuId");
        Capability projectMenuUpdate = Capability.builder(PROJECT_MENU_UPDATE)
                .description("全量编辑指定项目菜单的名称、类型、路由、图标和权限码；预览后强确认并检查菜单是否被并发修改")
                .permission("system:project:menu")
                .dataScope(DataScope.ALL)
                .params(Map.copyOf(projectMenuUpdateFields))
                .inputForm(
                        "agent.input.projectMenuUpdateTitle",
                        projectMenuUpdateFormFields,
                        optionalProjectMenuFields,
                        Map.of(),
                        Map.of("menuType", "platform.menu.type"))
                .outboundFields("id", "projectId", "menuName", "menuType", "permissionCode")
                .build();
        Capability dictTypeCreate = Capability.builder(DICT_TYPE_CREATE)
                .description("创建平台级字典类型；填写字典编码和名称，经预览确认后保存")
                .permission("system:dict:save")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "dictCode", new ParamSpec(ParamType.STRING, true, null, null, 128, null, null, null),
                        "dictName", new ParamSpec(ParamType.STRING, true, null, null, 128, null, null, null),
                        "description", ParamSpec.optionalString(512)))
                .inputForm(
                        "agent.input.dictTypeCreateTitle",
                        List.of("dictCode", "dictName", "description"),
                        Set.of("description"),
                        Map.of())
                .outboundFields("id", "dictCode", "dictName")
                .build();
        Capability dictItemCreate = Capability.builder(DICT_ITEM_CREATE)
                .description("给已有平台字典类型新增一个字典项；指定字典类型 ID、标签和值，预览确认后保存")
                .permission("system:dict:save")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "typeId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "itemLabel", new ParamSpec(ParamType.STRING, true, null, null, 128, null, null, null),
                        "itemValue", new ParamSpec(ParamType.STRING, true, null, null, 128, null, null, null),
                        "sortNo", new ParamSpec(ParamType.INT, false, 0, 9999, null, null, null, 0),
                        "defaultItem", new ParamSpec(ParamType.BOOL, false, null, null, null, null, null, false),
                        "color", ParamSpec.optionalString(32),
                        "labelI18nKey", ParamSpec.optionalString(160),
                        "status",
                                new ParamSpec(
                                        ParamType.ENUM,
                                        false,
                                        null,
                                        null,
                                        null,
                                        Set.of("ENABLED", "DISABLED"),
                                        null,
                                        "ENABLED")))
                .inputForm(
                        "agent.input.dictItemCreateTitle",
                        List.of(
                                "typeId",
                                "itemLabel",
                                "itemValue",
                                "sortNo",
                                "defaultItem",
                                "color",
                                "labelI18nKey",
                                "status"),
                        Set.of(),
                        Map.of(),
                        Map.of("status", "common.status"))
                .outboundFields("id", "itemLabel", "itemValue")
                .build();
        Capability dictTypeRename = Capability.builder(DICT_TYPE_RENAME)
                .description("修改平台级字典类型的名称；先查询字典 ID，预览现有名称和状态后确认；编码、状态及字典项保持不变")
                .permission("system:dict:save")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "typeId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "dictName", new ParamSpec(ParamType.STRING, true, null, null, 128, null, null, null)))
                .inputForm("agent.input.dictTypeRenameTitle", List.of("typeId", "dictName"), Set.of(), Map.of())
                .outboundFields("id", "dictCode", "dictName")
                .build();
        Capability dictItemRename = Capability.builder(DICT_ITEM_RENAME)
                .description("修改平台级字典项的标签；先查询字典类型 ID 和字典项 ID，预览原标签和值后确认；字典值与其他设置保持不变")
                .permission("system:dict:save")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "typeId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "itemId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "itemLabel", new ParamSpec(ParamType.STRING, true, null, null, 128, null, null, null)))
                .inputForm(
                        "agent.input.dictItemRenameTitle", List.of("typeId", "itemId", "itemLabel"), Set.of(), Map.of())
                .outboundFields("id", "itemLabel", "itemValue")
                .build();
        Capability dictItemDelete = Capability.builder(DICT_ITEM_DELETE)
                .description("删除平台级字典项；可能影响已有业务值的显示，必须确认字典类型 ID、字典项 ID、现有标签和值并强确认")
                .permission("system:dict:delete")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "typeId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "itemId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null)))
                .inputForm("agent.input.dictItemDeleteTitle", List.of("typeId", "itemId"), Set.of(), Map.of())
                .outboundFields("id")
                .build();
        Capability dictTypeDelete = Capability.builder(DICT_TYPE_DELETE)
                .description("删除平台级字典类型及其全部字典项；预览显示类型编码、名称及受影响项数，必须强确认")
                .permission("system:dict:delete")
                .dataScope(DataScope.ALL)
                .params(Map.of("typeId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null)))
                .inputForm("agent.input.dictTypeDeleteTitle", List.of("typeId"), Set.of(), Map.of())
                .outboundFields("id")
                .build();
        Capability configCreate = Capability.builder(CONFIG_CREATE)
                .description("创建平台级非敏感参数配置；配置值会出现在聊天预览中，不可用于密钥或个人信息，确认后保存")
                .permission("system:config:save")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "configKey", new ParamSpec(ParamType.STRING, true, null, null, 128, null, null, null),
                        "configValue", new ParamSpec(ParamType.STRING, true, null, null, 1000, null, null, null),
                        "valueType",
                                new ParamSpec(
                                        ParamType.ENUM,
                                        false,
                                        null,
                                        null,
                                        null,
                                        Set.of("STRING", "NUMBER", "BOOLEAN", "JSON"),
                                        null,
                                        "STRING"),
                        "description", ParamSpec.optionalString(512)))
                .inputForm(
                        "agent.input.configCreateTitle",
                        List.of("configKey", "configValue", "valueType", "description"),
                        Set.of("description"),
                        Map.of(),
                        Map.of("valueType", "config.value.type"))
                .outboundFields("id", "configKey", "valueType")
                .build();
        Capability configDelete = Capability.builder(CONFIG_DELETE)
                .description("删除平台级参数配置；只预览配置键、类型及状态，不展示配置值或密钥，必须强确认")
                .permission("system:config:delete")
                .dataScope(DataScope.ALL)
                .params(Map.of("configId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null)))
                .inputForm("agent.input.configDeleteTitle", List.of("configId"), Set.of(), Map.of())
                .outboundFields("id")
                .build();
        Capability userList = Capability.builder(USER_LIST)
                .description("查询平台用户列表，可按用户名或显示名搜索；仅返回身份和启用状态，不返回邮箱、密码或会话")
                .permission("system:user:list")
                .dataScope(DataScope.ALL)
                .params(Map.of("keyword", ParamSpec.optionalString(64), "pageSize", ParamSpec.pageSize(50, 20)))
                .outboundFields("id", "username", "displayName", "status")
                .verifiedReadOnly()
                .build();
        Capability userCreate = Capability.builder(USER_CREATE)
                .description("创建平台用户；只收集用户名、显示名称和可选邮箱，确认后服务端生成一次性初始密码，不向模型提供密码")
                .permission("system:user:create")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "username", new ParamSpec(ParamType.STRING, true, null, null, 64, null, null, null),
                        "displayName", new ParamSpec(ParamType.STRING, true, null, null, 100, null, null, null),
                        "email", ParamSpec.optionalString(200)))
                .inputForm(
                        "agent.input.userCreateTitle",
                        List.of("username", "displayName", "email"),
                        Set.of("email"),
                        Map.of())
                .outboundFields("id", "username", "displayName")
                .build();
        Capability userDisplayNameUpdate = Capability.builder(USER_DISPLAY_NAME_UPDATE)
                .description("修改平台用户的显示名称，不改变登录用户名或邮箱；先查询用户 ID，预览确认后执行")
                .permission("system:user:update")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "targetUserId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "displayName", new ParamSpec(ParamType.STRING, true, null, null, 100, null, null, null)))
                .inputForm(
                        "agent.input.userDisplayNameUpdateTitle",
                        List.of("targetUserId", "displayName"),
                        Set.of(),
                        Map.of())
                .outboundFields("id", "username", "displayName")
                .build();
        Capability userProfileUpdate = Capability.builder(USER_PROFILE_UPDATE)
                .description("完整修改平台用户的显示名称与邮箱；邮箱可清空，用户名不变，确认时检查资料是否已被其他人修改")
                .permission("system:user:update")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "targetUserId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "displayName", new ParamSpec(ParamType.STRING, true, null, null, 100, null, null, null),
                        "email", new ParamSpec(ParamType.STRING, true, null, null, 200, null, null, null)))
                .inputForm(
                        "agent.input.userProfileUpdateTitle",
                        List.of("targetUserId", "displayName", "email"),
                        Set.of(),
                        Map.of())
                .outboundFields("id", "username", "displayName")
                .build();
        Capability userPasswordReset = Capability.builder(USER_PASSWORD_RESET)
                .description("管理员为其他平台用户重置密码；强确认后由服务端生成一次性临时密码，仅首次结果展示，原有会话全部撤销且下次登录必须改密")
                .permission("system:user:reset-password")
                .dataScope(DataScope.ALL)
                .params(Map.of("targetUserId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null)))
                .inputForm("agent.input.userPasswordResetTitle", List.of("targetUserId"), Set.of(), Map.of())
                .outboundFields("id")
                .build();
        Capability userStatusUpdate = Capability.builder(USER_STATUS_UPDATE)
                .description("启用或停用平台用户；停用会撤销该用户全部在线会话，先查看目标用户和当前状态，再预览确认")
                .permission("system:user:status")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "targetUserId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "status",
                                new ParamSpec(
                                        ParamType.ENUM,
                                        true,
                                        null,
                                        null,
                                        null,
                                        Set.of("ENABLED", "DISABLED"),
                                        null,
                                        null)))
                .inputForm(
                        "agent.input.userStatusUpdateTitle",
                        List.of("targetUserId", "status"),
                        Set.of(),
                        Map.of(),
                        Map.of("status", "common.status"))
                .outboundFields("id", "username", "status")
                .build();
        Capability schedulerExecutions = Capability.builder(SCHEDULER_EXECUTION_LIST)
                .description("查询我参与项目的定时任务执行记录，可按项目或任务筛选；不展示执行日志正文")
                .permission("system:scheduler:list")
                .dataScope(DataScope.MEMBER_PROJECTS)
                .params(Map.of(
                        "projectId", ParamSpec.optionalVisibleProject(),
                        "jobId", ParamSpec.optionalString(64),
                        "pageSize", ParamSpec.pageSize(50, 20)))
                .outboundFields("id", "jobId", "jobName", "projectName", "status", "scheduledAt", "completedAt")
                .verifiedReadOnly()
                .build();
        Capability departmentList = Capability.builder(DEPARTMENT_LIST)
                .description("按层级分页查询平台部门基本信息；moreAvailable 表示还有下一页")
                .permission("system:org:list")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "page",
                        new ParamSpec(ParamType.INT, false, 1, 1000, null, null, null, 1),
                        "pageSize",
                        ParamSpec.pageSize(50, 20)))
                .outboundFields("id", "parentId", "name", "code", "status", "moreAvailable")
                .verifiedReadOnly()
                .build();
        Capability departmentCreate = Capability.builder(DEPARTMENT_CREATE)
                .description("创建平台部门，可指定上级部门；编码和名称必填，预览确认后保存")
                .permission("system:org:save")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "departmentName", new ParamSpec(ParamType.STRING, true, null, null, 100, null, null, null),
                        "departmentCode", new ParamSpec(ParamType.STRING, true, null, null, 64, null, null, null),
                        "parentDepartmentId", ParamSpec.optionalString(19),
                        "sortNo", new ParamSpec(ParamType.INT, false, 0, 9999, null, null, null, 0),
                        "status",
                                new ParamSpec(
                                        ParamType.ENUM,
                                        false,
                                        null,
                                        null,
                                        null,
                                        Set.of("ENABLED", "DISABLED"),
                                        null,
                                        "ENABLED")))
                .inputForm(
                        "agent.input.departmentCreateTitle",
                        List.of("departmentName", "departmentCode", "parentDepartmentId", "sortNo", "status"),
                        Set.of(),
                        Map.of(),
                        Map.of("status", "common.status"))
                .outboundFields("id", "name", "code", "parentId")
                .build();
        Capability departmentRename = Capability.builder(DEPARTMENT_RENAME)
                .description("修改平台部门名称；先查询部门 ID，预览现有名称、编码和层级后确认；编码、层级与状态保持不变")
                .permission("system:org:save")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "departmentId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "departmentName", new ParamSpec(ParamType.STRING, true, null, null, 100, null, null, null)))
                .inputForm(
                        "agent.input.departmentRenameTitle",
                        List.of("departmentId", "departmentName"),
                        Set.of(),
                        Map.of())
                .outboundFields("id", "name", "code", "parentId")
                .build();
        Capability departmentStatusUpdate = Capability.builder(DEPARTMENT_STATUS_UPDATE)
                .description("启用或停用平台部门；先查询部门 ID，预览当前名称、编码、层级和状态；停用须输入强确认短语")
                .permission("system:org:save")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "departmentId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "status",
                                new ParamSpec(
                                        ParamType.ENUM,
                                        true,
                                        null,
                                        null,
                                        null,
                                        Set.of("ENABLED", "DISABLED"),
                                        null,
                                        null)))
                .inputForm(
                        "agent.input.departmentStatusUpdateTitle",
                        List.of("departmentId", "status"),
                        Set.of(),
                        Map.of(),
                        Map.of("status", "common.status"))
                .outboundFields("id", "name", "code", "status")
                .build();
        Capability departmentDelete = Capability.builder(DEPARTMENT_DELETE)
                .description("删除没有子部门和用户归属的平台部门；预览目标部门后输入强确认短语")
                .permission("system:org:delete")
                .dataScope(DataScope.ALL)
                .params(Map.of("departmentId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null)))
                .inputForm("agent.input.departmentDeleteTitle", List.of("departmentId"), Set.of(), Map.of())
                .outboundFields("id", "name", "code", "parentId", "status")
                .build();
        Capability userDepartmentAssign = Capability.builder(USER_DEPARTMENT_ASSIGN)
                .description("全量替换平台用户的部门归属；列表首项为主部门，空列表清除归属，最多 20 个部门，需输入强确认短语")
                .permission("system:org:assign")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "targetUserId",
                        new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "departmentIds",
                        ParamSpec.stringList(true, 0, 20, 19)))
                .inputForm(
                        "agent.input.userDepartmentAssignTitle",
                        List.of("targetUserId", "departmentIds"),
                        Set.of(),
                        Map.of())
                .outboundFields("userId", "departmentIds")
                .build();
        Capability configs = Capability.builder(CONFIG_LIST)
                .description("分页查询平台级参数配置目录，不返回配置值或敏感配置键")
                .permission("system:config:list")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "page",
                        new ParamSpec(ParamType.INT, false, 1, 1000, null, null, null, 1),
                        "pageSize",
                        ParamSpec.pageSize(50, 20)))
                .outboundFields("id", "configKey", "valueType", "status", "description", "moreAvailable")
                .verifiedReadOnly()
                .build();
        Capability configDetail = Capability.builder(CONFIG_DETAIL)
                .description("按配置编号查询平台级非敏感参数配置的目录信息；不返回配置值或敏感配置键")
                .permission("system:config:list")
                .dataScope(DataScope.ALL)
                .params(Map.of("configId", new ParamSpec(ParamType.STRING, true, null, null, 64, null, null, null)))
                .outboundFields("id", "configKey", "valueType", "status", "description")
                .verifiedReadOnly()
                .build();
        Capability dictTypes = Capability.builder(DICT_TYPE_LIST)
                .description("分页查询平台级字典类型及状态")
                .permission("system:dict:list")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "page",
                        new ParamSpec(ParamType.INT, false, 1, 1000, null, null, null, 1),
                        "pageSize",
                        ParamSpec.pageSize(50, 20)))
                .outboundFields("id", "dictCode", "dictName", "status", "description", "moreAvailable")
                .verifiedReadOnly()
                .build();
        Capability dictItems = Capability.builder(DICT_ITEM_LIST)
                .description("分页查询指定平台字典的字典项")
                .permission("system:dict:list")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "typeId",
                        new ParamSpec(ParamType.STRING, true, null, null, 64, null, null, null),
                        "page",
                        new ParamSpec(ParamType.INT, false, 1, 1000, null, null, null, 1),
                        "pageSize",
                        ParamSpec.pageSize(50, 20)))
                .outboundFields("id", "itemLabel", "itemValue", "status", "moreAvailable")
                .verifiedReadOnly()
                .build();
        // 与 ProjectMemberController / ProjectRoleController 一致：这两项是平台级权限，
        // Controller 仅要求项目存在，不根据当前用户的项目成员身份再过滤。
        Capability projectMembers = Capability.builder(PROJECT_MEMBER_LIST)
                .description("分页查询指定项目的成员及角色，需要平台项目成员管理权限")
                .permission("system:project:member")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId",
                        new ParamSpec(ParamType.STRING, true, null, null, 64, null, null, null),
                        "page",
                        new ParamSpec(ParamType.INT, false, 1, 1000, null, null, null, 1),
                        "pageSize",
                        ParamSpec.pageSize(50, 20)))
                .outboundFields("userId", "username", "displayName", "status", "roleIds", "moreAvailable")
                .verifiedReadOnly()
                .build();
        Capability projectMemberSave = Capability.builder(PROJECT_MEMBER_SAVE)
                .description("向项目添加已有平台用户，或全量调整现有成员的角色与状态；角色必须属于当前项目，需输入强确认短语")
                .permission("system:project:member")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "targetUserId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "roleIds", ParamSpec.stringList(true, 1, 100, 19),
                        "status",
                                new ParamSpec(
                                        ParamType.ENUM,
                                        true,
                                        null,
                                        null,
                                        null,
                                        Set.of("ACTIVE", "DISABLED"),
                                        null,
                                        null)))
                .inputForm(
                        "agent.input.projectMemberSaveTitle",
                        List.of("projectId", "targetUserId", "roleIds", "status"),
                        Set.of(),
                        Map.of(),
                        Map.of("status", "project.member.status"))
                .outboundFields("userId", "username", "displayName", "status", "roleIds")
                .build();
        Capability projectMemberDelete = Capability.builder(PROJECT_MEMBER_DELETE)
                .description("从指定项目移除非创建人的成员；会撤销其项目角色，需输入强确认短语")
                .permission("system:project:member")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null),
                        "targetUserId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null)))
                .inputForm(
                        "agent.input.projectMemberDeleteTitle",
                        List.of("projectId", "targetUserId"),
                        Set.of(),
                        Map.of())
                .outboundFields("userId", "username", "displayName", "status", "roleIds")
                .build();
        Capability projectRoles = Capability.builder(PROJECT_ROLE_LIST)
                .description("分页查询指定项目的角色及状态，需要平台项目角色管理权限")
                .permission("system:project:role")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId",
                        new ParamSpec(ParamType.STRING, true, null, null, 64, null, null, null),
                        "page",
                        new ParamSpec(ParamType.INT, false, 1, 1000, null, null, null, 1),
                        "pageSize",
                        ParamSpec.pageSize(50, 20)))
                .outboundFields("id", "roleCode", "roleName", "status", "builtIn", "moreAvailable")
                .verifiedReadOnly()
                .build();
        // 安全运营中心是平台级权限；详情/变更 diff/IP/traceId 不进入模型。
        Capability operationLogs = Capability.builder(OPERATION_LOG_LIST)
                .description("分页查询平台操作审计摘要，可按用户名和模块筛选；不展示操作详情或字段变更内容")
                .permission("system:audit:list")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "username", ParamSpec.optionalString(64),
                        "module", ParamSpec.optionalString(64),
                        "page", new ParamSpec(ParamType.INT, false, 1, 1000, null, null, null, 1),
                        "pageSize", ParamSpec.pageSize(50, 20)))
                .outboundFields("id", "username", "module", "operation", "responseStatus", "createdAt", "moreAvailable")
                .verifiedReadOnly()
                .build();
        Capability loginLogs = Capability.builder(LOGIN_LOG_LIST)
                .description("分页查询平台登录审计摘要，可按用户名和结果筛选；不展示失败消息、IP 或追踪标识")
                .permission("system:audit:list")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "username", ParamSpec.optionalString(64),
                        "status", ParamSpec.optionalString(24),
                        "page", new ParamSpec(ParamType.INT, false, 1, 1000, null, null, null, 1),
                        "pageSize", ParamSpec.pageSize(50, 20)))
                .outboundFields("id", "username", "status", "createdAt", "moreAvailable")
                .verifiedReadOnly()
                .build();
        Capability sessions = Capability.builder(SESSION_LIST)
                .description("分页查询平台会话状态，可按用户名和状态筛选；只返回状态和时间，不返回会话标识")
                .permission("system:session:list")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "username", ParamSpec.optionalString(64),
                        "status", ParamSpec.optionalString(24),
                        "page", new ParamSpec(ParamType.INT, false, 1, 1000, null, null, null, 1),
                        "pageSize", ParamSpec.pageSize(50, 20)))
                .outboundFields("username", "status", "createdAt", "lastSeenAt", "expiresAt", "moreAvailable")
                .verifiedReadOnly()
                .build();
        Capability aiStatus = Capability.builder(AI_PROVIDER_STATUS)
                .description("查询平台 AI 服务配置状态和最近测试结果；不返回服务地址、密钥或错误详情")
                .permission("system:ai:list")
                .dataScope(DataScope.ALL)
                .params(Map.of())
                .outboundFields("providerName", "model", "apiKeyConfigured", "lastTestStatus", "lastTestAt")
                .verifiedReadOnly()
                .build();
        Capability i18nMessages = Capability.builder(I18N_MESSAGE_LIST)
                .description("分页查询平台国际化资源目录，可按资源键筛选；不返回文案正文和各语言译文")
                .permission("system:i18n:list")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "keyword", ParamSpec.optionalString(64),
                        "page", new ParamSpec(ParamType.INT, false, 1, 1000, null, null, null, 1),
                        "pageSize", ParamSpec.pageSize(50, 20)))
                .outboundFields(
                        "id",
                        "messageKey",
                        "moduleCode",
                        "publicVisible",
                        "requiredResource",
                        "status",
                        "moreAvailable")
                .verifiedReadOnly()
                .build();
        Capability i18nLocales = Capability.builder(I18N_LOCALE_LIST)
                .description("查询平台语言开放和译文覆盖状态")
                .permission("system:i18n:list")
                .dataScope(DataScope.ALL)
                .params(Map.of())
                .outboundFields(
                        "locale",
                        "label",
                        "selectableConfigured",
                        "selectable",
                        "missingRequiredResources",
                        "missingMenus",
                        "missingDictionaryItems")
                .verifiedReadOnly()
                .build();
        Capability projectMenus = Capability.builder(PROJECT_MENU_LIST)
                .description("分页查询指定项目的菜单名称、类型和状态；不返回路由、组件路径或权限码")
                .permission("system:project:menu")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "projectId", new ParamSpec(ParamType.STRING, true, null, null, 64, null, null, null),
                        "page", new ParamSpec(ParamType.INT, false, 1, 1000, null, null, null, 1),
                        "pageSize", ParamSpec.pageSize(50, 20)))
                .outboundFields("id", "parentId", "menuName", "menuType", "visible", "status", "moreAvailable")
                .verifiedReadOnly()
                .build();
        return java.util.stream.Stream.of(
                        projectCreate,
                        projectStatusUpdate,
                        projectRename,
                        projectRoleCreate,
                        projectRoleUpdate,
                        projectRoleDelete,
                        projectRoleStatusUpdate,
                        projectRoleMenuGrant,
                        projectMenuStatusUpdate,
                        projectMenuDelete,
                        projectMenuCreate,
                        projectMenuUpdate,
                        dictTypeCreate,
                        dictItemCreate,
                        dictTypeRename,
                        dictItemRename,
                        dictItemDelete,
                        dictTypeDelete,
                        configCreate,
                        configDelete,
                        projectList,
                        projectDetail,
                        generationList,
                        generationDetail,
                        schedulerList,
                        userList,
                        userCreate,
                        userDisplayNameUpdate,
                        userProfileUpdate,
                        userPasswordReset,
                        userStatusUpdate,
                        schedulerExecutions,
                        departmentList,
                        departmentCreate,
                        departmentRename,
                        departmentStatusUpdate,
                        departmentDelete,
                        userDepartmentAssign,
                        configs,
                        configDetail,
                        dictTypes,
                        dictItems,
                        projectMembers,
                        projectMemberSave,
                        projectMemberDelete,
                        projectRoles,
                        operationLogs,
                        loginLogs,
                        sessions,
                        aiStatus,
                        i18nMessages,
                        i18nLocales,
                        projectMenus)
                .collect(java.util.stream.Collectors.toUnmodifiableMap(Capability::code, value -> value));
    }

    /**
     * 按调用者权限裁剪后的能力清单。
     *
     * <p><b>这一步必须发生在接触模型之前。</b>用户没有权限的能力绝不能出现在提示词里：
     * 先给模型再过滤等于把目录泄露给模型，也给了它「建议你去申请权限」这类越界输出的
     * 机会（ADR 0030 第 5 条）。</p>
     */
    public List<Capability> visibleTo(KaiwuContext actor) {
        return java.util.stream.Stream.concat(
                        capabilities.values().stream()
                                .filter(capability -> actor.hasPermission(capability.permission())),
                        remote == null
                                ? java.util.stream.Stream.empty()
                                : java.util.stream.Stream.concat(
                                        remote.visibleTo(actor).stream(), remote.visibleWritesTo(actor).stream()))
                .sorted(java.util.Comparator.comparing(Capability::code))
                .toList();
    }

    /** 完整的 System 本地声明，供管理页展示覆盖范围；聊天规划仍只使用 visibleTo。 */
    public List<Capability> localCapabilities() {
        return capabilities.values().stream()
                .sorted(java.util.Comparator.comparing(Capability::code))
                .toList();
    }

    /** 仅在该能力对调用者可见时返回；越权查找与不存在一律得到空值。 */
    public Optional<Capability> findVisible(String code, KaiwuContext actor) {
        if (remote != null && !code.startsWith("system.")) {
            Optional<Capability> read = remote.findVisible(code, actor);
            return read.isPresent() ? read : remote.findVisibleWrite(code, actor);
        }
        return Optional.ofNullable(capabilities.get(code))
                .filter(capability -> actor.hasPermission(capability.permission()));
    }

    /** 写计划还要再核对一次写目录，不能仅凭 Capability 的只读/幂等布尔值放行。 */
    public boolean isApprovedWrite(Capability capability, KaiwuContext actor) {
        return remote != null
                && remote.findVisibleWrite(capability.code(), actor)
                        .filter(capability::equals)
                        .isPresent();
    }

    public int size() {
        return capabilities.size();
    }
}
