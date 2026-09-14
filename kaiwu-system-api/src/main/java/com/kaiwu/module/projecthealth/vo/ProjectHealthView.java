package com.kaiwu.module.projecthealth.vo;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 项目体检报告（ADR 0012）。
 *
 * <p>只包含检查结论与版本号，**不含任何被读取的文件内容**——体检记录不得成为业务代码的
 * 副本。</p>
 *
 * @param projectId 被体检的项目
 * @param enabled   项目是否允许平台只读体检；关闭后平台不再访问该仓库
 * @param verdict   汇总结论：PASS / WARN / FAIL / UNKNOWN
 * @param checkedAt 体检时间；为 null 表示从未体检过
 * @param checks    各检查项明细
 */
public record ProjectHealthView(
        String projectId, boolean enabled, String verdict, LocalDateTime checkedAt, List<CheckView> checks) {

    /**
     * @param code    检查项标识，如 {@code backend.gate.permission}
     * @param name    中文名，供界面直接展示
     * @param verdict PASS / WARN / FAIL / UNKNOWN
     * @param detail  一句话说明；UNKNOWN 时说明为什么无法确认
     */
    public record CheckView(String code, String name, String verdict, String detail) {}
}
