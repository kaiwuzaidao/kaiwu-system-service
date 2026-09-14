package com.kaiwu.module.metadata.vo;

import java.time.LocalDateTime;

/**
 * @param dictName    已按请求语言解析的展示名；管理端列表直接渲染即可
 * @param dictNameKey 引用的国际化资源 key；非空即启用引用式国际化（ADR 0014）
 * @param sortNo      显示顺序；越小越靠前，由管理端拖拽维护
 */
public record DictTypeView(
        String id,
        String scopeId,
        String dictCode,
        String dictName,
        String dictNameKey,
        boolean inheritGlobal,
        int sortNo,
        String status,
        String description,
        LocalDateTime updatedAt) {}
