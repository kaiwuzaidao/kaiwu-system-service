package com.kaiwu.module.factory.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.factory.model.ColumnMeta;
import com.kaiwu.module.factory.model.TableMeta;
import com.kaiwu.module.factory.renderer.DdlParser;
import com.kaiwu.module.factory.service.ProjectBlueprintService;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationCreateRequest;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import tools.jackson.databind.ObjectMapper;

/**
 * 将用户提供的 DDL（或空项目）收敛为可校验的项目蓝图；不调用任何模型（ADR 0038）。
 */
@Service("projectBlueprintService")
public class ProjectBlueprintServiceImpl implements ProjectBlueprintService {

    private static final int MAX_TABLES = 100;
    private static final int MAX_COLUMNS = 3000;

    private final DdlParser ddlParser;
    private final ObjectMapper objectMapper;

    public ProjectBlueprintServiceImpl(DdlParser ddlParser, ObjectMapper objectMapper) {
        this.ddlParser = ddlParser;
        this.objectMapper = objectMapper;
    }

    /**
     * 由 DDL 生成受管的项目蓝图（ADR 0006）；蓝图校验后才交给确定性脚手架。
     */
    public ProjectBlueprint create(ProjectView project, ProjectGenerationCreateRequest request) {
        if ("BASIC_SCAFFOLD".equals(request.generationMode()) || "ADOPT_FRONTEND".equals(request.generationMode())) {
            return new ProjectBlueprint(
                    request.generationMode(),
                    null,
                    null,
                    "基础空项目脚手架",
                    List.of(),
                    blueprintJson(
                            project, request.generationMode(), null, "基础空项目脚手架", "DETERMINISTIC_FALLBACK", List.of()));
        }
        if ("DDL_SCAFFOLD".equals(request.generationMode())) {
            return ddlScaffold(project, request);
        }
        // AI_PROJECT 已下线（ADR 0038）；历史任务重试在服务层已被拒绝，这里兜底。
        throw new ApiException(HttpStatus.BAD_REQUEST, "该生成模式已下线，请使用基础脚手架", "api.common.badRequest");
    }

    /**
     * DDL 确定性生成（ADR 0035）：解析用户提供的 DDL 直接交给脚手架，不调用也不读取任何 AI 配置。
     *
     * <p>元数据补全固定为确定性兜底结果，因此同一份 DDL 在任何环境都生成相同的产物。</p>
     */
    private ProjectBlueprint ddlScaffold(ProjectView project, ProjectGenerationCreateRequest request) {
        if (!StringUtils.hasText(request.ddl())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "DDL 确定性生成必须提供 DDL", "api.common.badRequest");
        }
        String ddl = request.ddl().trim();
        List<TableMeta> tables = ddlParser.parseAll(ddl);
        validateSize(tables);
        String summary = "已根据 DDL 确定性生成数据模型与后台模块";
        return new ProjectBlueprint(
                "DDL_SCAFFOLD",
                ddl,
                null,
                summary,
                tables,
                blueprintJson(project, "DDL_SCAFFOLD", ddl, summary, "DETERMINISTIC_FALLBACK", tables));
    }

    private void validateSize(List<TableMeta> tables) {
        if (tables.size() > MAX_TABLES) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目表数量超过上限 " + MAX_TABLES, "api.common.badRequest");
        }
        int columns =
                tables.stream().mapToInt(table -> table.getColumns().size()).sum();
        if (columns > MAX_COLUMNS) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目字段数量超过上限 " + MAX_COLUMNS, "api.common.badRequest");
        }
    }

    private String blueprintJson(
            ProjectView project,
            String mode,
            String ddl,
            String summary,
            String metadataGenerationMode,
            List<TableMeta> tables) {
        Map<String, Object> blueprint = new LinkedHashMap<>();
        blueprint.put("contractVersion", "1");
        blueprint.put("projectCode", project.projectCode());
        blueprint.put("generationMode", mode);
        blueprint.put("metadataGenerationMode", metadataGenerationMode);
        blueprint.put("designSummary", summary);
        blueprint.put("ddl", ddl);
        blueprint.put(
                "modules",
                tables.stream()
                        .map(table -> {
                            Map<String, Object> module = new LinkedHashMap<>();
                            module.put("table", table.getTableName());
                            module.put("entity", table.getEntityName());
                            module.put("moduleCode", moduleCode(table.getTableName()));
                            module.put("moduleName", safeText(table.getComment()));
                            module.put("accessScope", table.accessScope());
                            module.put(
                                    "ownerColumn",
                                    table.ownerColumn() == null
                                            ? null
                                            : table.ownerColumn().getColumnName());
                            module.put(
                                    "fields",
                                    table.getColumns().stream().map(this::field).toList());
                            return module;
                        })
                        .toList());
        try {
            return objectMapper.writeValueAsString(blueprint);
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "项目蓝图序列化失败", "api.common.internalError");
        }
    }

    private Map<String, Object> field(ColumnMeta column) {
        Map<String, Object> value = new LinkedHashMap<>();
        value.put("column", column.getColumnName());
        value.put("field", column.getFieldName());
        value.put("javaType", column.getJavaType());
        value.put("label", column.getLabel());
        value.put("searchable", column.isSearchable());
        return value;
    }

    static String moduleCode(String tableName) {
        String value = tableName.toLowerCase(Locale.ROOT);
        for (String prefix : List.of("biz_", "t_", "sys_", "tb_")) {
            if (value.startsWith(prefix)) {
                value = value.substring(prefix.length());
                break;
            }
        }
        String normalized = value.replaceAll("[^a-z0-9]", "");
        return normalized.isBlank() ? "business" : normalized;
    }

    private static String safeText(String value) {
        if (!StringUtils.hasText(value)) return "业务模块";
        return value.replace("\r", " ").replace("\n", " ").trim();
    }
}
