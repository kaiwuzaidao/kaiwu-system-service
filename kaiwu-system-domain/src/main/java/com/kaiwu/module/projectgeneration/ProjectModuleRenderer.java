package com.kaiwu.module.projectgeneration;

import com.kaiwu.module.codegen.model.TableMeta;
import com.kaiwu.module.project.vo.ProjectView;
import java.util.LinkedHashMap;
import java.util.Map;

/** 将一个已校验的数据表渲染为前后端业务模块。 */
final class ProjectModuleRenderer {

    private final ScaffoldTemplateSupport templates;

    ProjectModuleRenderer(ScaffoldTemplateSupport templates) {
        this.templates = templates;
    }

    ProjectScaffoldGenerator.GeneratedModule render(
            ProjectView project,
            TableMeta table,
            String moduleCode,
            String modulePageName,
            String moduleName,
            String resourceCode) {
        Map<String, String> backend = new LinkedHashMap<>();
        Map<String, String> frontend = new LinkedHashMap<>();
        String permissionPrefix = moduleCode + ":" + resourceCode;
        Map<String, Object> variables =
                templates.moduleVariables(project, table, moduleCode, moduleName, resourceCode, permissionPrefix);
        variables.put("modulePageName", modulePageName);
        String packagePath = project.packageName().replace('.', '/');
        String modulePrefix = "kaiwu-" + project.projectCode();
        String apiBase = modulePrefix + "-api/src/main/java/" + packagePath + "/module/" + moduleCode;
        String javaBase = modulePrefix + "-domain/src/main/java/" + packagePath + "/module/" + moduleCode;
        String entity = table.getEntityName();
        backend.put(
                javaBase + "/entity/" + entity + ".java",
                templates.render("project/backend/Entity.java.ftl", variables));
        backend.put(
                javaBase + "/mapper/" + entity + "Mapper.java",
                templates.render("project/backend/Mapper.java.ftl", variables));
        backend.put(
                javaBase + "/service/" + entity + "Service.java",
                templates.render("project/backend/Service.java.ftl", variables));
        backend.put(
                javaBase + "/controller/" + entity + "Controller.java",
                templates.render("project/backend/Controller.java.ftl", variables));
        String testBase = modulePrefix + "-domain/src/test/java/" + packagePath + "/module/" + moduleCode;
        backend.put(
                testBase + "/service/" + entity + "ServiceTest.java",
                templates.render("project/backend/ServiceTest.java.ftl", variables));
        backend.put(
                testBase + "/controller/" + entity + "ControllerTest.java",
                templates.render("project/backend/ControllerTest.java.ftl", variables));
        backend.put(
                apiBase + "/dto/" + entity + "SaveRequest.java",
                templates.render("project/backend/SaveRequest.java.ftl", variables));
        backend.put(
                apiBase + "/vo/" + entity + "View.java", templates.render("project/backend/View.java.ftl", variables));
        frontend.put(
                "src/pages/" + modulePageName + "/index.tsx",
                templates.render("project/frontend/module-page.tsx.ftl", variables));
        frontend.put(
                "src/services/" + moduleCode + ".ts",
                templates.render("project/frontend/module-service.ts.ftl", variables));
        String menuSql = templates.render("project/backend/menu.sql.ftl", variables);
        return new ProjectScaffoldGenerator.GeneratedModule(
                moduleCode,
                modulePageName,
                moduleName,
                resourceCode,
                permissionPrefix,
                table,
                Map.copyOf(backend),
                Map.copyOf(frontend),
                menuSql);
    }
}
