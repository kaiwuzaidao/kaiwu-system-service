package com.kaiwu.module.projectgeneration;

import com.kaiwu.module.codegen.CodegenTemplateRenderer;
import com.kaiwu.module.codegen.model.TableMeta;
import com.kaiwu.module.project.vo.ProjectView;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Service;

/**
 * 从同一份 ProjectBlueprint 编排后端、前端和业务模块的确定性渲染。
 *
 * <p>具体文件集合由聚焦的 renderer 负责；本类只保留跨仓组装顺序和公开结果契约。</p>
 */
@Service
public class ProjectScaffoldGenerator {

    public static final String TEMPLATE_VERSION = "kaiwu-project-v13";

    /**
     * 生成项目依赖的 Starter 版本，也是项目体检判断平台当前版本的唯一事实源。
     */
    public static final String STARTER_VERSION = "0.1.0";

    private final ScaffoldTemplateSupport templates;
    private final BackendScaffoldRenderer backendRenderer;
    private final FrontendScaffoldRenderer frontendRenderer;
    private final ProjectModuleRenderer moduleRenderer;

    public ProjectScaffoldGenerator(CodegenTemplateRenderer renderer) {
        this.templates = new ScaffoldTemplateSupport(renderer);
        this.backendRenderer = new BackendScaffoldRenderer(templates);
        this.frontendRenderer = new FrontendScaffoldRenderer(templates);
        this.moduleRenderer = new ProjectModuleRenderer(templates);
    }

    /**
     * 按蓝图确定性地生成前后端源码。
     *
     * <p>「确定性」指同样的蓝图必然产出同样的文件——生成过程不调用 AI，
     * 只做模板渲染，因此结果可复现、可评审。</p>
     */
    public GeneratedRepositories generate(ProjectView project, ProjectBlueprintService.ProjectBlueprint blueprint) {
        Map<String, Object> root = templates.rootVariables(project);
        Map<String, String> backend = backendRenderer.root(root, project, blueprint);
        Map<String, String> frontend = frontendRenderer.root(root);
        List<GeneratedModule> modules = renderModules(project, blueprint);

        modules.forEach(module -> {
            backend.putAll(module.backendFiles());
            frontend.putAll(module.frontendFiles());
        });
        backendRenderer.complete(backend, project, modules);
        frontendRenderer.complete(frontend, project, modules);
        String manifest = projectManifest(project, blueprint, modules);
        backend.put("docs/kaiwu-project-blueprint.json", manifest);
        frontend.put("docs/kaiwu-project-blueprint.json", manifest);
        return new GeneratedRepositories(Map.copyOf(backend), Map.copyOf(frontend), List.copyOf(modules));
    }

    private List<GeneratedModule> renderModules(
            ProjectView project, ProjectBlueprintService.ProjectBlueprint blueprint) {
        List<GeneratedModule> modules = new ArrayList<>();
        Set<String> moduleCodes = new LinkedHashSet<>();
        for (TableMeta table : blueprint.tables()) {
            templates.sanitizeMetadata(table);
            String businessStem = templates.businessStem(table.getTableName(), project.projectCode());
            String resourceCode = ScaffoldTemplateSupport.compactCode(businessStem);
            String moduleCode = templates.uniqueModuleCode(resourceCode, moduleCodes);
            modules.add(moduleRenderer.render(
                    project,
                    table,
                    moduleCode,
                    ScaffoldTemplateSupport.javaClassName(businessStem),
                    ScaffoldTemplateSupport.safeText(table.getComment()),
                    resourceCode));
        }
        return modules;
    }

    private String projectManifest(
            ProjectView project, ProjectBlueprintService.ProjectBlueprint blueprint, List<GeneratedModule> modules) {
        String moduleLines = modules.stream()
                .map(module ->
                        """
                    {"table":"%s","moduleCode":"%s","permissionPrefix":"%s","accessScope":"%s","ownerColumn":%s}"""
                                .formatted(
                                        ScaffoldTemplateSupport.json(
                                                module.table().getTableName()),
                                        ScaffoldTemplateSupport.json(module.moduleCode()),
                                        ScaffoldTemplateSupport.json(module.permissionPrefix()),
                                        module.table().accessScope(),
                                        module.table().ownerColumn() == null
                                                ? "null"
                                                : "\""
                                                        + ScaffoldTemplateSupport.json(module.table()
                                                                .ownerColumn()
                                                                .getColumnName())
                                                        + "\""))
                .reduce((left, right) -> left + ",\n" + right)
                .orElse("");
        return """
                {
                  "contractVersion": "1",
                  "templateVersion": "%s",
                  "projectId": "%s",
                  "projectCode": "%s",
                  "generationMode": "%s",
                  "designSummary": "%s",
                  "supportedLocales": ["zh-CN"],
                  "modules": [
                %s
                  ]
                }
                """
                .formatted(
                        TEMPLATE_VERSION,
                        project.id(),
                        ScaffoldTemplateSupport.json(project.projectCode()),
                        ScaffoldTemplateSupport.json(blueprint.generationMode()),
                        ScaffoldTemplateSupport.json(blueprint.designSummary()),
                        moduleLines);
    }

    public record GeneratedRepositories(
            Map<String, String> backendFiles, Map<String, String> frontendFiles, List<GeneratedModule> modules) {}

    public record GeneratedModule(
            String moduleCode,
            String modulePageName,
            String moduleName,
            String resourceCode,
            String permissionPrefix,
            TableMeta table,
            Map<String, String> backendFiles,
            Map<String, String> frontendFiles,
            String menuSql) {}

    public record ApiColumn(
            String fieldName,
            String apiType,
            String toEntityExpression,
            String toViewExpression,
            boolean nullable,
            boolean stringValue) {}
}
