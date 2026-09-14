package com.kaiwu.module.projectgeneration.vo;

/**
 * 从 MySQL 只读导入的结构预览。
 */
public record MysqlSchemaImportView(String database, int tableCount, int columnCount, String ddl) {}
