package com.kaiwu.module.factory.renderer;

import com.kaiwu.module.project.vo.ProjectView;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** 组装生成项目的 Umi 前端仓库及其路由、语言包和首页。 */
final class FrontendScaffoldRenderer {

    private final ScaffoldTemplateSupport templates;

    FrontendScaffoldRenderer(ScaffoldTemplateSupport templates) {
        this.templates = templates;
    }

    Map<String, String> root(Map<String, Object> variables) {
        Map<String, String> files = new LinkedHashMap<>();
        for (String path : List.of(
                "src/providers/ProjectAccessProvider.tsx",
                "src/services/request.ts",
                "src/services/platform.ts",
                "src/utils/accessToken.ts",
                "src/hooks/useProjectId.ts",
                "src/hooks/useManagedDictionary.ts",
                "src/hooks/useProjectConfig.ts",
                "scripts/check-kaiwu-sdk.mjs",
                "scripts/frontend-permissions.mjs",
                "docs/kaiwu-integration-lock.json",
                "src/kaiwu/index.tsx",
                ".gitlab/merge_request_templates/Product-Handoff.md",
                "mock/index.ts",
                "mock-support/platform.ts",
                "mock-support/shared.ts",
                "mock-support/http.ts",
                "mock-support/manifest.cjs",
                "mock-support/manifest.d.cts",
                "scripts/check-dist.mjs",
                "scripts/check-runtime-image.sh",
                ".dockerignore",
                "mock-support/requests.ts")) {
            files.put(path, templates.render("project/frontend/product/" + path + ".ftl", variables));
        }
        files.put(
                ".npmrc",
                """
                registry=https://registry.npmjs.org/
                min-release-age=7
                strict-peer-dependencies=false
                store-dir=.pnpm-store
                network-concurrency=8
                fetch-retries=5
                fetch-retry-mintimeout=1000
                fetch-retry-maxtimeout=15000
                fetch-timeout=120000
                """);
        files.put("package.json", templates.render("project/frontend/package.json.ftl", variables));
        files.put(".prettierrc.json", templates.render("project/frontend/prettierrc.json.ftl", variables));
        files.put("pnpm-lock.yaml", templates.render("project/frontend/pnpm-lock.yaml.ftl", variables));
        files.put("tsconfig.json", templates.render("project/frontend/tsconfig.json.ftl", variables));
        files.put("typings.d.ts", templates.render("project/frontend/typings.d.ts.ftl", variables));
        files.put("src/app.tsx", templates.render("project/frontend/app.tsx.ftl", variables));
        files.put("src/utils/projectMenu.ts", templates.render("project/frontend/project-menu.ts.ftl", variables));
        files.put("src/services/todos.ts", templates.render("project/frontend/todos.ts.ftl", variables));
        files.put("src/pages/Todos/index.tsx", templates.render("project/frontend/todos-page.tsx.ftl", variables));
        files.put("src/global.less", templates.render("project/frontend/global.less.ftl", variables));
        files.put("src/theme/tokens.ts", templates.render("project/frontend/theme-tokens.ts.ftl", variables));
        files.put("src/theme/antd.ts", templates.render("project/frontend/theme-antd.ts.ftl", variables));
        files.put("src/theme/layout.ts", templates.render("project/frontend/theme-layout.ts.ftl", variables));
        files.put("src/theme/ant-pro.less", templates.render("project/frontend/theme-ant-pro.less.ftl", variables));
        files.put(
                "src/components/LineIcon/index.tsx", templates.render("project/frontend/line-icon.tsx.ftl", variables));
        files.put(
                "src/kaiwu/ProjectAccessProvider.tsx",
                templates.render("project/frontend/project-access-provider.tsx.ftl", variables));
        files.put(
                "src/components/PermissionButton/index.tsx",
                templates.render("project/frontend/permission-button.tsx.ftl", variables));
        // 顶栏操作区：全局搜索、切换项目、当前用户、站内信。与平台端同款，
        // 生成项目一落地就有和 Kaiwu System 一致的观感，不必各自再造一遍。
        files.put(
                "src/components/RightContent/index.tsx",
                templates.render("project/frontend/right-content.tsx.ftl", variables));
        files.put(
                "src/components/GlobalSearch/index.tsx",
                templates.render("project/frontend/global-search.tsx.ftl", variables));
        files.put(
                "src/components/NotificationBell/index.tsx",
                templates.render("project/frontend/notification-bell.tsx.ftl", variables));
        files.put(
                "src/components/ManagedDictSelect/index.tsx",
                templates.render("project/frontend/managed-dict-select.tsx.ftl", variables));
        files.put(
                "src/components/ManagedDictText/index.tsx",
                templates.render("project/frontend/managed-dict-text.tsx.ftl", variables));
        files.put("src/kaiwu/useProjectId.ts", templates.render("project/frontend/use-project-id.ts.ftl", variables));
        files.put(
                "src/kaiwu/useManagedDictionary.ts",
                templates.render("project/frontend/use-managed-dictionary.ts.ftl", variables));
        files.put(
                "src/kaiwu/useProjectConfig.ts",
                templates.render("project/frontend/use-project-config.ts.ftl", variables));
        files.put("src/kaiwu/request.ts", templates.render("project/frontend/request.ts.ftl", variables));
        // 项目成员与角色授权：平台提供接口，每个业务后台默认带这两个页面（权限码 access:*）。
        files.put(
                "src/services/projectAccess.ts", templates.render("project/frontend/project-access.ts.ftl", variables));
        files.put(
                "src/pages/ProjectMembers/index.tsx",
                templates.render("project/frontend/project-members.tsx.ftl", variables));
        files.put(
                "src/pages/ProjectRoles/index.tsx",
                templates.render("project/frontend/project-roles.tsx.ftl", variables));
        // 项目内统一文件记录（ADR 0041）：接口在 Starter，菜单与权限由平台种入，随开关生成。
        if (templates.fileRegistry()) {
            files.put(
                    "src/services/projectFiles.ts",
                    templates.render("project/frontend/project-files.ts.ftl", variables));
            files.put(
                    "src/pages/ProjectFiles/index.tsx",
                    templates.render("project/frontend/project-files.tsx.ftl", variables));
        }
        // 平台侧接口（用户、站内信、全局搜索、可切换项目）的统一转调。
        files.put("src/kaiwu/platform.ts", templates.render("project/frontend/platform.ts.ftl", variables));
        files.put("src/kaiwu/accessToken.ts", templates.render("project/frontend/access-token.ts.ftl", variables));
        files.put(
                "scripts/check-dict-consistency.mjs",
                templates.render("project/frontend/check-dict-consistency.mjs.ftl", variables));
        files.put(
                "scripts/check-permission-consistency.mjs",
                templates.render("project/frontend/check-permission-consistency.mjs.ftl", variables));
        files.put(
                "scripts/check-log-redaction.mjs",
                templates.render("project/frontend/check-log-redaction.mjs.ftl", variables));
        files.put(
                "scripts/check-constraints.sh", templates.render("project/common/check-constraints.sh.ftl", variables));
        files.put("scripts/dev-real.cjs", templates.render("project/frontend/dev-real.cjs.ftl", variables));
        files.put("scripts/dev.sh", templates.render("project/frontend/dev.sh.ftl", variables));
        files.put("docs/kaiwu-constraints.json", templates.render("project/common/constraints.json.ftl", variables));
        files.put(
                "docs/kaiwu-constraint-waivers.json",
                templates.render("project/common/constraint-waivers.json.ftl", variables));
        files.put("Dockerfile", templates.render("project/frontend/Dockerfile.ftl", variables));
        files.put("nginx.conf", templates.render("project/frontend/nginx.conf.ftl", variables));
        files.put("deploy/server/compose.yml", templates.render("project/frontend/compose.server.yml.ftl", variables));
        files.put(
                "deploy/server/nginx-locations.conf",
                templates.render("project/frontend/nginx-locations.conf.ftl", variables));
        files.put(
                "deploy/k8s/deployment.yaml", templates.render("project/frontend/k8s-deployment.yaml.ftl", variables));
        files.put("deploy/k8s/service.yaml", templates.render("project/frontend/k8s-service.yaml.ftl", variables));
        files.put(
                "deploy/k8s/gateway-service.yaml",
                templates.render("project/frontend/k8s-gateway-service.yaml.ftl", variables));
        files.put("deploy/k8s/ingress.yaml", templates.render("project/frontend/k8s-ingress.yaml.ftl", variables));
        files.put(
                "deploy/k8s/kustomization.yaml",
                templates.render("project/frontend/k8s-kustomization.yaml.ftl", variables));
        files.put("README.md", templates.render("project/frontend/README.md.ftl", variables));
        files.put("AGENTS.md", templates.render("project/frontend/AGENTS.md.ftl", variables));
        files.put("CLAUDE.md", templates.render("project/frontend/CLAUDE.md.ftl", variables));
        files.put(".gitlab-ci.yml", templates.render("project/frontend/gitlab-ci.yml.ftl", variables));
        // 流水线的 verify:configuration 要求本文件存在且三个值非空。
        files.put("ci.env", templates.render("project/frontend/ci-env.ftl", variables));
        files.put(
                ".gitignore",
                """
                node_modules/
                .pnpm-store/
                .umi/
                .umi-production/
                dist/
                .idea/
                .vscode/
                .env
                .env.*
                """);
        return files;
    }

    void complete(
            Map<String, String> files, ProjectView project, List<ProjectScaffoldGenerator.GeneratedModule> modules) {
        files.put("config/config.ts", config(project, modules));
        files.put("src/locales/zh-CN.ts", locale(modules, false));
        files.put("src/pages/Home/index.tsx", home(project, modules));
    }

    private String locale(List<ProjectScaffoldGenerator.GeneratedModule> modules, boolean english) {
        StringBuilder menus = new StringBuilder();
        menus.append("  'menu.home': '").append(english ? "Home" : "项目首页").append("',\n");
        for (ProjectScaffoldGenerator.GeneratedModule module : modules) {
            String translated = module.table() == null ? null : module.table().getCommentEn();
            boolean hasTranslation = english && translated != null && !translated.isBlank();
            menus.append("  'menu.")
                    .append(module.moduleCode())
                    .append("': '")
                    .append(ScaffoldTemplateSupport.ts(hasTranslation ? translated : module.moduleName()))
                    .append("',\n");
        }
        menus.append("  'menu.todos': '待办',\n");
        menus.append("  'menu.project-members': '")
                .append(english ? "Project members" : "项目成员")
                .append("',\n");
        menus.append("  'menu.project-roles': '")
                .append(english ? "Role access" : "角色授权")
                .append("',\n");
        if (templates.fileRegistry()) {
            menus.append("  'menu.project-files': '")
                    .append(english ? "Files" : "文件")
                    .append("',\n");
        }
        menus.append("  'home.welcome': '欢迎使用项目工作台',\n");
        menus.append("  'home.description': '选择业务入口，开始今天的工作。',\n");
        menus.append("  'home.moduleHint': '进入模块查看和办理业务。',\n");
        menus.append("  'home.enter': '进入{name}',\n");
        menus.append("  'home.empty': '项目暂未开放业务功能，请联系项目管理员。',\n");
        menus.append("  'home.noAccess': '暂无可用业务入口，请联系项目管理员开通权限。',\n");
        menus.append("  'home.missingProject': '请从平台工作台重新进入当前项目。',\n");
        menus.append("  'home.failed': '项目权限加载失败，请重试。',\n");
        menus.append("  'home.retry': '重试',\n");
        menus.append("  'todos.description': '这里显示当前项目需要你处理的事项，办理后由业务服务自动更新。',\n");
        menus.append("  'todos.title': '待办事项',\n");
        menus.append("  'todos.time': '收到时间',\n");
        menus.append("  'todos.handle': '去办理',\n");
        menus.append("  'todos.refresh': '刷新',\n");
        menus.append("  'todos.empty': '暂无待办事项',\n");
        menus.append("  'todos.failed': '待办加载失败，请重试。',\n");
        menus.append("  'todos.unavailable': '待办暂不可用',\n");
        menus.append("  'todos.noLink': '请联系项目管理员确认办理入口',\n");
        menus.append("  'common.action.retry': '重试',\n");
        return """
                /**
                 * %s 语言包。
                 *
                 * 语言跟随平台账户偏好，由 ProjectAccessProvider 设置，本前端不提供语言切换器。
                 * 当前项目只声明 zh-CN；增加语言时先更新 manifest 的 supportedLocales，
                 * 再为已启用语言补齐同一组 key。
                 */
                export default {
                %s
                  // 通用
                  'common.action.create': '%s',
                  'common.action.edit': '%s',
                  'common.action.delete': '%s',
                  'common.action.confirm': '%s',
                  'common.action.cancel': '%s',
                  'common.action.search': '%s',
                  'common.action.reset': '%s',
                  'common.action.export': '%s',
                  'common.deleteConfirm': '%s',
                  'common.saveSuccess': '%s',
                  'common.deleteSuccess': '%s',
                  'common.operation': '%s',
                  'common.createdAt': '%s',
                  'common.updatedAt': '%s',
                  'common.empty': '%s',
                  // 请求层与后端错误：messageKey 命中不了时用这两条兜底
                  'common.error.unavailable': '%s',
                  'common.error.request': '%s',
                  'error.validation.failed': '%s',
                  'error.internal': '%s',
                };
                """
                .formatted(
                        english ? "English" : "简体中文",
                        menus.toString().stripTrailing(),
                        english ? "Create" : "新增",
                        english ? "Edit" : "编辑",
                        english ? "Delete" : "删除",
                        english ? "OK" : "确定",
                        english ? "Cancel" : "取消",
                        english ? "Search" : "查询",
                        english ? "Reset" : "重置",
                        english ? "Export" : "导出",
                        english ? "Delete this record?" : "确认删除该记录？",
                        english ? "Saved" : "保存成功",
                        english ? "Deleted" : "删除成功",
                        english ? "Actions" : "操作",
                        english ? "Created at" : "创建时间",
                        english ? "Updated at" : "更新时间",
                        english ? "No data" : "暂无数据",
                        english ? "Service is temporarily unavailable, please retry." : "服务暂时不可用，请稍后重试",
                        english ? "Request failed (HTTP {status})" : "请求失败（HTTP {status}）",
                        // 纯占位符，两种语言一致，不需要按语言分支。
                        "{detail}",
                        english ? "Internal server error" : "服务内部错误");
    }

    private String config(ProjectView project, List<ProjectScaffoldGenerator.GeneratedModule> modules) {
        StringBuilder routes = new StringBuilder();
        routes.append(
                """
                {
                      path: '/',
                      name: 'home',
                      icon: 'DashboardOutlined',
                      component: './Home',
                    }""");
        for (ProjectScaffoldGenerator.GeneratedModule module : modules) {
            routes.append(",\n    {\n")
                    .append("      path: '/")
                    .append(module.moduleCode())
                    .append("',\n")
                    .append("      name: '")
                    .append(module.moduleCode())
                    .append("',\n")
                    .append("      component: './")
                    .append(module.modulePageName())
                    .append("',\n")
                    .append("    }");
        }
        // 平台提供的项目成员与角色授权页面，排在业务模块之后，权限由平台的 access:* 码控制。
        routes.append(
                """
                ,
                    {
                      path: '/todos',
                      name: 'todos',
                      component: './Todos',
                    },
                    {
                      path: '/project-members',
                      name: 'project-members',
                      component: './ProjectMembers',
                    },
                    {
                      path: '/project-roles',
                      name: 'project-roles',
                      component: './ProjectRoles',
                    }""");
        if (templates.fileRegistry()) {
            routes.append(
                    """
                    ,
                        {
                          path: '/project-files',
                          name: 'project-files',
                          component: './ProjectFiles',
                        }""");
        }
        // trailingComma: all 要求数组最后一项也带逗号；无论有没有业务模块，末项都是 routes 的末项。
        routes.append(",");
        return """
                import { defineConfig } from '@umijs/max';
                import { kaiwuTheme } from '../src/theme/antd';

                export default defineConfig({
                  hash: true,
                  antd: {
                    appConfig: {},
                    configProvider: {
                      theme: kaiwuTheme,
                    },
                  },
                  locale: {
                    default: 'zh-CN',
                    // 语言跟随平台账户偏好（ProjectAccessProvider 里设置），
                    // 不认浏览器语言、不写 localStorage，避免与平台不同步。
                    baseNavigator: false,
                    useLocalStorage: false,
                    antd: true,
                    title: true,
                  },
                  layout: {
                    title: '%s',
                    locale: true,
                    siderWidth: 256,
                  },
                  base: '/apps/%s/',
                  publicPath: '/apps/%s/',
                  routes: [
                    %s
                  ],
                  proxy:
                    process.env.MOCK === 'none'
                      ? Object.fromEntries(
                          ['/api', '/%s-api', '/%s-svc'].map((path) => [
                            path,
                            { target: process.env.KAIWU_GATEWAY || 'http://127.0.0.1:8088', changeOrigin: true },
                          ]),
                        )
                      : {},
                  npmClient: 'pnpm',
                });
                """
                .formatted(
                        ScaffoldTemplateSupport.ts(project.projectName()),
                        project.projectCode(),
                        project.projectCode(),
                        routes,
                        project.projectCode(),
                        project.projectCode());
    }

    /** 首页只展示有权限的业务入口；不向业务用户暴露脚手架状态、表名或开发步骤。 */
    private String home(ProjectView project, List<ProjectScaffoldGenerator.GeneratedModule> modules) {
        String entries = modules.stream()
                .map(module -> "  { path: '/%s', key: 'menu.%s', permission: '%s:list' },"
                        .formatted(
                                ScaffoldTemplateSupport.ts(module.moduleCode()),
                                ScaffoldTemplateSupport.ts(module.moduleCode()),
                                ScaffoldTemplateSupport.ts(module.permissionPrefix())))
                .collect(java.util.stream.Collectors.joining("\n"));
        return templates.render("project/frontend/home.tsx.ftl", Map.of("homeEntries", entries));
    }
}
