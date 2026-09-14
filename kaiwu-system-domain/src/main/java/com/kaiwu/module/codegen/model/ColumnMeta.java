package com.kaiwu.module.codegen.model;

public class ColumnMeta {
    private String columnName;
    private String fieldName;
    private String javaType;
    private String comment;
    private boolean primaryKey;
    private boolean nullable = true;
    private boolean logicDelete;
    private boolean autoFillTime;
    private boolean searchable;
    private String label;

    public String getColumnName() {
        return columnName;
    }

    public void setColumnName(String columnName) {
        this.columnName = columnName;
    }

    public String getFieldName() {
        return fieldName;
    }

    public void setFieldName(String fieldName) {
        this.fieldName = fieldName;
    }

    public String getJavaType() {
        return javaType;
    }

    public void setJavaType(String javaType) {
        this.javaType = javaType;
    }

    public String getComment() {
        return comment;
    }

    public void setComment(String comment) {
        this.comment = comment;
    }

    public boolean isPrimaryKey() {
        return primaryKey;
    }

    public void setPrimaryKey(boolean primaryKey) {
        this.primaryKey = primaryKey;
    }

    public boolean isNullable() {
        return nullable;
    }

    public void setNullable(boolean nullable) {
        this.nullable = nullable;
    }

    public boolean isLogicDelete() {
        return logicDelete;
    }

    public void setLogicDelete(boolean logicDelete) {
        this.logicDelete = logicDelete;
    }

    public boolean isAutoFillTime() {
        return autoFillTime;
    }

    public void setAutoFillTime(boolean autoFillTime) {
        this.autoFillTime = autoFillTime;
    }

    public boolean isSearchable() {
        return searchable;
    }

    public void setSearchable(boolean searchable) {
        this.searchable = searchable;
    }

    public String getLabel() {
        return label;
    }

    public void setLabel(String label) {
        this.label = label;
    }
}
