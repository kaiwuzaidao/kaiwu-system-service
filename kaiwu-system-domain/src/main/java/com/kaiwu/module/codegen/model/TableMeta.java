package com.kaiwu.module.codegen.model;

import java.util.ArrayList;
import java.util.List;

public class TableMeta {
    private String tableName;
    private String entityName;
    private String comment;
    /** 英文菜单名。仅 AI 增强路径会填充；为空时前端语言包沿用 comment 原文。 */
    private String commentEn;

    private List<ColumnMeta> columns = new ArrayList<>();

    public ColumnMeta primaryKey() {
        return columns.stream().filter(ColumnMeta::isPrimaryKey).findFirst().orElse(null);
    }

    /**
     * 按 ADR 0021 的确定性命名约定识别资源归属列。
     *
     * <p>模型不能提供任意策略表达式；只有显式的用户归属列才生成 OWNER_ONLY。</p>
     */
    public ColumnMeta ownerColumn() {
        return columns.stream()
                .filter(column -> "owner_user_id".equalsIgnoreCase(column.getColumnName())
                        || "global_user_id".equalsIgnoreCase(column.getColumnName()))
                .findFirst()
                .orElse(null);
    }

    public String accessScope() {
        return ownerColumn() == null ? "PROJECT_WIDE" : "OWNER_ONLY";
    }

    /** 可编辑列：排除主键与审计列——它们由框架维护，出现在表单里只会被误改。 */
    public List<ColumnMeta> editableColumns() {
        return columns.stream()
                .filter(column -> !column.isPrimaryKey()
                        && !column.isLogicDelete()
                        && !column.isAutoFillTime()
                        && column != ownerColumn())
                .toList();
    }

    public List<ColumnMeta> searchColumns() {
        return columns.stream().filter(ColumnMeta::isSearchable).toList();
    }

    public String getTableName() {
        return tableName;
    }

    public void setTableName(String tableName) {
        this.tableName = tableName;
    }

    public String getEntityName() {
        return entityName;
    }

    public void setEntityName(String entityName) {
        this.entityName = entityName;
    }

    public String getComment() {
        return comment;
    }

    public void setComment(String comment) {
        this.comment = comment;
    }

    public String getCommentEn() {
        return commentEn;
    }

    public void setCommentEn(String commentEn) {
        this.commentEn = commentEn;
    }

    public List<ColumnMeta> getColumns() {
        return columns;
    }

    public void setColumns(List<ColumnMeta> columns) {
        this.columns = columns;
    }
}
