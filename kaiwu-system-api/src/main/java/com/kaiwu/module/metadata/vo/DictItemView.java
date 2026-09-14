package com.kaiwu.module.metadata.vo;

/**
 * @param itemLabel    已按请求语言解析的展示标签；消费端直接渲染即可
 * @param labelI18nKey 引用的国际化资源 key；非空即启用引用式国际化（ADR 0014）
 */
public record DictItemView(
        String id,
        String itemLabel,
        String itemValue,
        int sortNo,
        boolean defaultItem,
        String color,
        String extraJson,
        String labelI18nKey,
        String status) {}
