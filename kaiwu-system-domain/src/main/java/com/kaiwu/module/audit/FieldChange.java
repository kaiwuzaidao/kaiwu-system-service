package com.kaiwu.module.audit;

/**
 * 审计日志字段级变更条目：改动了哪个字段、改前是什么、改后是什么。
 * 调用方自行保证不传入 password / token / 密钥类字段。
 */
public record FieldChange(String field, String before, String after) {}
