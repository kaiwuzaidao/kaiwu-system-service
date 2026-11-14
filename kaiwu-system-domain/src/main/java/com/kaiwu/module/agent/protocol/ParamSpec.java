package com.kaiwu.module.agent.protocol;

import java.util.Set;

/**
 * 单个能力参数的定义。
 *
 * <p>{@code enumFrom} 表示候选值由服务端按当前调用者注入，模型只能从中选择——
 * 参数候选值的权限裁剪落在这里。只裁剪能力而放任参数，模型仍会凭问题里的名字
 * 编造出无权项目的调用（ADR 0030 第 5 条）。</p>
 *
 * @param values 固定枚举取值；与 {@code enumFrom} 互斥
 * @param enumFrom 动态候选来源，目前只支持 {@link #VISIBLE_PROJECTS}
 */
public record ParamSpec(
        ParamType type,
        boolean required,
        Integer min,
        Integer max,
        Integer maxLength,
        Set<String> values,
        String enumFrom,
        Object defaultValue) {

    /** 候选值为调用者有成员关系的项目。 */
    public static final String VISIBLE_PROJECTS = "VISIBLE_PROJECTS";

    public ParamSpec {
        if (type == null) {
            throw new IllegalArgumentException("参数类型不能为空");
        }
        if (values != null && enumFrom != null) {
            throw new IllegalArgumentException("values 与 enumFrom 互斥，不能同时声明");
        }
        if (enumFrom != null && !VISIBLE_PROJECTS.equals(enumFrom)) {
            throw new IllegalArgumentException("未知的候选来源：" + enumFrom);
        }
        if (type == ParamType.STRING_LIST
                && (min == null
                        || max == null
                        || min < 0
                        || max < min
                        || max > 100
                        || maxLength == null
                        || maxLength < 1
                        || maxLength > 4000
                        || values != null
                        || enumFrom != null
                        || defaultValue != null)) {
            throw new IllegalArgumentException("字符串列表必须声明元素数量和单项长度上限");
        }
        values = values == null ? null : Set.copyOf(values);
    }

    public static ParamSpec optionalString(int maxLength) {
        return new ParamSpec(ParamType.STRING, false, null, null, maxLength, null, null, null);
    }

    public static ParamSpec optionalBool() {
        return new ParamSpec(ParamType.BOOL, false, null, null, null, null, null, null);
    }

    public static ParamSpec optionalDateTime() {
        return new ParamSpec(ParamType.DATETIME, false, null, null, null, null, null, null);
    }

    public static ParamSpec optionalEnum(Set<String> values) {
        return new ParamSpec(ParamType.ENUM, false, null, null, null, values, null, null);
    }

    /** 由服务端注入候选项目的参数；模型不得给出清单之外的值。 */
    public static ParamSpec optionalVisibleProject() {
        return new ParamSpec(ParamType.STRING, false, null, null, null, null, VISIBLE_PROJECTS, null);
    }

    /** 分页大小一律带上下限与默认值，防止一次提问拖垮数据库、撑爆上下文。 */
    public static ParamSpec pageSize(int max, int defaultValue) {
        return new ParamSpec(ParamType.INT, false, 1, max, null, null, null, defaultValue);
    }

    public static ParamSpec stringList(boolean required, int minItems, int maxItems, int maxItemLength) {
        return new ParamSpec(ParamType.STRING_LIST, required, minItems, maxItems, maxItemLength, null, null, null);
    }
}
