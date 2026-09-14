package com.kaiwu.module.codegen;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.codegen.model.ColumnMeta;
import com.kaiwu.module.codegen.model.TableMeta;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;
import net.sf.jsqlparser.parser.CCJSqlParserUtil;
import net.sf.jsqlparser.statement.Statement;
import net.sf.jsqlparser.statement.create.index.CreateIndex;
import net.sf.jsqlparser.statement.create.table.ColumnDefinition;
import net.sf.jsqlparser.statement.create.table.CreateTable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * 只接受标准 CREATE TABLE，并把 DDL 收敛为确定性模板模型。
 */
@Component
public class DdlParser {

    private static final Set<String> SEARCH_HINT =
            Set.of("name", "code", "title", "no", "status", "type", "phone", "username", "nick_name");

    /** 解析建表 DDL 为表元数据；解析失败按可修正的输入错误抛出，而不是 500。 */
    public List<TableMeta> parseAll(String ddl) {
        try {
            List<Statement> statements = CCJSqlParserUtil.parseStatements(ddl).getStatements();
            if (statements.isEmpty()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "未找到 CREATE TABLE 语句", "api.common.badRequest");
            }
            List<TableMeta> tables = new ArrayList<>();
            for (Statement statement : statements) {
                if (statement instanceof CreateTable createTable) {
                    tables.add(parseCreateTable(createTable));
                } else if (!(statement instanceof CreateIndex)) {
                    throw new ApiException(
                            HttpStatus.BAD_REQUEST, "仅支持 CREATE TABLE 和 CREATE INDEX 语句", "api.common.badRequest");
                }
            }
            if (tables.isEmpty()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "未找到 CREATE TABLE 语句", "api.common.badRequest");
            }
            return List.copyOf(tables);
        } catch (ApiException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "DDL 解析失败，请粘贴标准 CREATE TABLE：" + exception.getMessage(),
                    "api.common.badRequest");
        }
    }

    private TableMeta parseCreateTable(CreateTable createTable) {
        TableMeta table = new TableMeta();
        String tableName = strip(createTable.getTable().getName());
        table.setTableName(tableName);
        table.setEntityName(toPascal(tableName));
        table.setComment(extractTableComment(createTable));

        Set<String> primaryKeys = createTable.getIndexes() == null
                ? Set.of()
                : createTable.getIndexes().stream()
                        .filter(index -> index.getType() != null
                                && index.getType().toUpperCase(Locale.ROOT).contains("PRIMARY"))
                        .flatMap(index -> index.getColumnsNames().stream())
                        .map(this::strip)
                        .collect(Collectors.toSet());

        for (ColumnDefinition definition : createTable.getColumnDefinitions()) {
            ColumnMeta column = new ColumnMeta();
            String columnName = strip(definition.getColumnName());
            List<String> specs = definition.getColumnSpecs();
            column.setColumnName(columnName);
            column.setFieldName(toCamel(columnName));
            column.setJavaType(mapType(definition.getColDataType().getDataType()));
            column.setComment(extractComment(specs));
            column.setPrimaryKey(primaryKeys.contains(columnName) || contains(specs, "PRIMARY", "KEY"));
            column.setNullable(!contains(specs, "NOT", "NULL"));
            column.setLogicDelete("deleted".equalsIgnoreCase(columnName));
            column.setAutoFillTime("created_at".equalsIgnoreCase(columnName)
                    || "updated_at".equalsIgnoreCase(columnName)
                    || "create_time".equalsIgnoreCase(columnName)
                    || "update_time".equalsIgnoreCase(columnName));
            column.setSearchable(!column.isPrimaryKey()
                    && !column.isLogicDelete()
                    && !column.isAutoFillTime()
                    && "String".equals(column.getJavaType())
                    && SEARCH_HINT.contains(columnName.toLowerCase(Locale.ROOT)));
            column.setLabel(
                    column.getComment() == null || column.getComment().isBlank()
                            ? column.getFieldName()
                            : column.getComment());
            table.getColumns().add(column);
        }
        if (table.getColumns().isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CREATE TABLE 不包含字段", "api.common.badRequest");
        }
        if (table.primaryKey() == null) {
            table.getColumns().getFirst().setPrimaryKey(true);
        }
        return table;
    }

    private String extractTableComment(CreateTable table) {
        String options = table.getTableOptionsStrings() == null ? "" : String.join(" ", table.getTableOptionsStrings());
        java.util.regex.Matcher matcher = java.util.regex.Pattern.compile(
                        "(?i)COMMENT\\s*(?:=\\s*)?['\"]([^'\"]+)['\"]")
                .matcher(options);
        return matcher.find() ? matcher.group(1) : table.getTable().getName();
    }

    private String extractComment(List<String> specs) {
        if (specs == null) return null;
        for (int i = 0; i < specs.size() - 1; i++) {
            if ("COMMENT".equalsIgnoreCase(specs.get(i))) {
                return specs.get(i + 1).replaceAll("^['\"]|['\"]$", "");
            }
        }
        return null;
    }

    private boolean contains(List<String> specs, String first, String second) {
        if (specs == null) return false;
        for (int i = 0; i < specs.size() - 1; i++) {
            if (first.equalsIgnoreCase(specs.get(i)) && second.equalsIgnoreCase(specs.get(i + 1))) {
                return true;
            }
        }
        return false;
    }

    private String mapType(String sqlType) {
        String type = sqlType == null ? "" : sqlType.toUpperCase(Locale.ROOT).split("[ (]")[0];
        return switch (type) {
            case "BIGINT" -> "Long";
            case "INT", "INTEGER", "TINYINT", "SMALLINT", "MEDIUMINT" -> "Integer";
            case "DECIMAL", "NUMERIC" -> "BigDecimal";
            case "DOUBLE", "FLOAT", "REAL" -> "Double";
            case "BIT", "BOOLEAN", "BOOL" -> "Boolean";
            case "DATE" -> "LocalDate";
            case "DATETIME", "TIMESTAMP" -> "LocalDateTime";
            default -> "String";
        };
    }

    private String strip(String value) {
        return value == null ? null : value.replace("`", "").replace("\"", "").trim();
    }

    private String toCamel(String value) {
        String[] parts = value.toLowerCase(Locale.ROOT).split("_");
        StringBuilder result = new StringBuilder(parts[0]);
        for (int index = 1; index < parts.length; index++) {
            if (!parts[index].isEmpty()) {
                result.append(Character.toUpperCase(parts[index].charAt(0))).append(parts[index].substring(1));
            }
        }
        return result.toString();
    }

    private String toPascal(String value) {
        String camel = toCamel(value);
        return Character.toUpperCase(camel.charAt(0)) + camel.substring(1);
    }
}
