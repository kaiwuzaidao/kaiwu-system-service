package com.kaiwu.module.project.vo;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

/**
 * 某个受控资源在 Context 里的归约结果（docs/DATA_SCOPE.md §4）。
 *
 * <p>{@code all} 与 {@code set} 二选一：{@code all=true} 表示项目内全部；否则 {@code set} 是部门字典下标，
 * 空数组表示只看本人。两者都用 {@link JsonInclude.Include#NON_NULL}，未使用的那个不出现在 JSON 里。</p>
 *
 * @param all 项目内全部数据，只会是 {@code true} 或缺省
 * @param set 部门字典下标，升序、去重；空数组表示仅本人
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record DataScopeRuleView(Boolean all, List<Integer> set) {

    /** 项目内全部。 */
    public static DataScopeRuleView everything() {
        return new DataScopeRuleView(Boolean.TRUE, null);
    }

    /** 本人加给定部门字典下标。 */
    public static DataScopeRuleView departments(List<Integer> indexes) {
        return new DataScopeRuleView(null, List.copyOf(indexes));
    }
}
