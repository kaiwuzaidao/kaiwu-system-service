package com.kaiwu.module.project.model;

import java.util.Optional;

/**
 * 数据范围类型（ADR 0044、docs/DATA_SCOPE.md §3）。
 *
 * <p>这是协议常量而不是可运营的字典：Starter 依据它生成 SQL 谓词，随意新增值等于无法执行的授权。
 * 名称同时是数据库 {@code scope_type}、{@code allowedScopes} 与 {@code roles.yml} 里的取值。</p>
 */
public enum DataScopeType {

    /** 项目内全部。 */
    ALL,

    /** 用户全部所属部门及其下级。 */
    DEPT_AND_CHILD,

    /** 用户全部所属部门，不含下级。 */
    DEPT,

    /** 仅本人；未配置时的固定默认。 */
    SELF,

    /** 管理员勾选的部门，可选含下级。 */
    CUSTOM_DEPT;

    /** 按名称精确解析，空白或未知值返回空，不做大小写宽容，避免配置里的拼写差异被悄悄放行。 */
    public static Optional<DataScopeType> parse(String value) {
        if (value == null) {
            return Optional.empty();
        }
        for (DataScopeType type : values()) {
            if (type.name().equals(value)) {
                return Optional.of(type);
            }
        }
        return Optional.empty();
    }
}
