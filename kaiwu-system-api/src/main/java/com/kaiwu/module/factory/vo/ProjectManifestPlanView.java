package com.kaiwu.module.factory.vo;

import java.util.List;

/**
 * 平台资源清单的同步计划（ADR 0036、ADR 0042）。
 *
 * @param planHash           本次计划的摘要；执行时必须原样带回
 * @param changes            新增、更新、源环境已删除与漂移条目；没有变化的条目不列出
 * @param missingPermissions 执行所需但当前用户缺少的平台权限码；非空时不能执行
 * @param hasBaseline        目标项目是否有过成功的移交记录；没有时无法识别「源环境已删除」
 * @param alreadyApplied     同一移交包摘要是否已成功导入过；没有时为 {@code null}
 */
public record ProjectManifestPlanView(
        String planHash,
        List<Change> changes,
        List<String> missingPermissions,
        boolean hasBaseline,
        AlreadyApplied alreadyApplied) {

    /** 不带基线与重复导入信息的计划，命令行与旧调用方使用。 */
    public ProjectManifestPlanView(String planHash, List<Change> changes, List<String> missingPermissions) {
        this(planHash, changes, missingPermissions, false, null);
    }

    /**
     * 一个条目的计划动作。
     *
     * @param resource DICT / DICT_ITEM / CONFIG / MENU / I18N / ROLE / ROLE_GRANT
     * @param key      资源的稳定标识，例如 dictCode、dictCode:value、配置键、权限码、路由或 角色/授权键
     * @param action   CREATE / UPDATE / DRIFT / REMOVED_AT_SOURCE；DRIFT 只报告，不执行
     * @param detail   人可读的差异说明
     * @param category NORMAL 随计划执行；ACCESS 需勾选导入授权；DELETE 需逐项勾选
     */
    public record Change(String resource, String key, String action, String detail, String category) {

        /** 普通条目，随计划执行或仅报告。 */
        public Change(String resource, String key, String action, String detail) {
            this(resource, key, action, detail, "NORMAL");
        }
    }

    /**
     * 已导入过同一移交包的记录。
     *
     * @param handoverId 移交记录 ID
     * @param appliedAt  执行时间，ISO-8601
     * @param operatorId 执行人用户 ID
     */
    public record AlreadyApplied(String handoverId, String appliedAt, String operatorId) {}
}
