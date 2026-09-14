package com.kaiwu.module.projectgeneration;

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
        files.put(
                "src/providers/ProjectAccessProvider.tsx",
                templates.render("project/frontend/project-access-provider.tsx.ftl", variables));
        files.put(
                "src/components/PermissionButton/index.tsx",
                templates.render("project/frontend/permission-button.tsx.ftl", variables));
        // 侧栏底部区域：全局搜索、切换项目、当前用户、站内信。与平台端同款，
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
        files.put("src/hooks/useProjectId.ts", templates.render("project/frontend/use-project-id.ts.ftl", variables));
        files.put(
                "src/hooks/useManagedDictionary.ts",
                templates.render("project/frontend/use-managed-dictionary.ts.ftl", variables));
        files.put(
                "src/hooks/useProjectConfig.ts",
                templates.render("project/frontend/use-project-config.ts.ftl", variables));
        files.put("src/services/request.ts", templates.render("project/frontend/request.ts.ftl", variables));
        // 平台侧接口（用户、站内信、全局搜索、可切换项目）的统一转调。
        files.put("src/services/platform.ts", templates.render("project/frontend/platform.ts.ftl", variables));
        files.put("src/utils/accessToken.ts", templates.render("project/frontend/access-token.ts.ftl", variables));
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
        // trailingComma: all 要求数组最后一项也带逗号；无论有没有业务模块，末项都是 routes 的末项。
        routes.append(",");
        return """
                import { defineConfig } from '@umijs/max';

                export default defineConfig({
                  hash: true,
                  antd: {
                    appConfig: {},
                    configProvider: {
                      theme: {
                        token: {
                          colorPrimary: '#4f46e5',
                          colorLink: '#4f46e5',
                          borderRadius: 6,
                          fontSize: 14,
                        },
                        components: {
                          Layout: {
                            headerBg: '#ffffff',
                            siderBg: '#ffffff',
                            bodyBg: '#f5f6fa',
                          },
                          Menu: {
                            itemSelectedBg: 'rgba(79,70,229,0.08)',
                            itemSelectedColor: '#4f46e5',
                            itemHoverBg: 'rgba(79,70,229,0.04)',
                          },
                          Card: { borderRadiusLG: 10 },
                        },
                      },
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
                    siderWidth: 216,
                  },
                  base: '/apps/%s/',
                  publicPath: '/apps/%s/',
                  routes: [
                    %s
                  ],
                  // 独立 `pnpm dev` 时把业务请求转给本机 Gateway（8088）。
                  // 没有这段，/%s-api/** 会打到 dev server 自己身上直接 404——
                  // 从 Kaiwu 主站进入时走的是主站同源加载，不经过这里。
                  proxy: {
                    '/%s-api': {
                      target: 'http://127.0.0.1:8088',
                      changeOrigin: true,
                    },
                  },
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

    private String home(ProjectView project, List<ProjectScaffoldGenerator.GeneratedModule> modules) {
        String cards = modules.isEmpty()
                ? "<Alert type=\"info\" message=\"基础脚手架已生成，请在仓库中新增第一个业务模块。\" />"
                : modules.stream()
                        .map(module ->
                                """
                        <Card title="%s" extra={<a href="./%s">进入</a>}>
                          <Typography.Text type="secondary">%s</Typography.Text>
                        </Card>"""
                                        .formatted(
                                                ScaffoldTemplateSupport.ts(module.moduleName()),
                                                module.moduleCode(),
                                                ScaffoldTemplateSupport.ts(
                                                        module.table().getTableName())))
                        .reduce((left, right) -> left + "\n" + right)
                        .orElse("");
        // 占位符处在 8 空格缩进上，文本块只替首行；续行必须补齐，否则生成的 JSX 顶格。
        cards = cards.replace("\n", "\n        ");
        return """
                import { PageContainer } from '@ant-design/pro-components';
                import { Alert, Card, Space, Typography } from 'antd';

                export default function HomePage() {
                  return (
                    <PageContainer title="%s">
                      <Space direction="vertical" size={16} style={{ width: '100%%' }}>
                        <Alert
                          type="success"
                          showIcon
                          message="项目第一版已由 Kaiwu 脚手架生成"
                          description="后续代码由本仓库独立维护，平台不会再次覆盖。"
                        />
                        %s
                      </Space>
                    </PageContainer>
                  );
                }
                """
                .formatted(ScaffoldTemplateSupport.ts(project.projectName()), cards);
    }
}
