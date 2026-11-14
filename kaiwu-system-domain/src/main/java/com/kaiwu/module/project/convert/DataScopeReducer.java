package com.kaiwu.module.project.convert;

import com.kaiwu.module.project.model.DataScopeType;
import java.util.ArrayDeque;
import java.util.Collection;
import java.util.Deque;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 把一个用户在某资源上的全部角色配置归约成最终范围（docs/DATA_SCOPE.md §3）。
 *
 * <p>纯函数，不访问数据库：部门树和用户所属部门由调用方准备。归约结果只有两种形态——
 * {@code all}，或「本人加部门集合」；未配置、用户没有部门、部门已不存在都向变窄的方向退化。</p>
 */
public final class DataScopeReducer {

    private DataScopeReducer() {}

    /**
     * 单个角色在某资源上的配置。
     *
     * @param type         范围类型
     * @param includeChild 仅 {@code CUSTOM_DEPT} 有意义
     * @param deptIds      仅 {@code CUSTOM_DEPT} 使用的部门 ID
     */
    public record RoleScope(DataScopeType type, boolean includeChild, Set<String> deptIds) {

        /** 复制集合，避免调用方之后修改影响归约。 */
        public RoleScope {
            deptIds = deptIds == null ? Set.of() : Set.copyOf(deptIds);
        }

        /** 不带部门的配置，用于 ALL、DEPT、DEPT_AND_CHILD、SELF。 */
        public static RoleScope of(DataScopeType type) {
            return new RoleScope(type, false, Set.of());
        }
    }

    /**
     * 归约结果。
     *
     * @param all     是否项目内全部；为 {@code true} 时 {@code deptIds} 无意义
     * @param deptIds 部门集合，隐含本人；为空表示仅本人
     */
    public record Reduction(boolean all, Set<String> deptIds) {

        /** 复制集合并在 {@code all} 时清空，保证相等性只取决于语义。 */
        public Reduction {
            deptIds = all || deptIds == null ? Set.of() : Set.copyOf(deptIds);
        }

        /** 项目内全部。 */
        public static Reduction everything() {
            return new Reduction(true, Set.of());
        }

        /** 仅本人。 */
        public static Reduction selfOnly() {
            return new Reduction(false, Set.of());
        }
    }

    /**
     * 归约。
     *
     * @param roleScopes 用户各有效角色在该资源上的显式配置；没有显式配置的角色不必出现，它贡献的是仅本人
     * @param userDepts  用户全部所属部门，不论是否主部门
     * @param childrenOf 部门 ID 到直接下级 ID 列表，用于展开下级
     */
    public static Reduction reduce(
            Collection<RoleScope> roleScopes, Set<String> userDepts, Map<String, List<String>> childrenOf) {
        Set<String> departments = new LinkedHashSet<>();
        for (RoleScope scope : roleScopes) {
            switch (scope.type()) {
                case ALL -> {
                    return Reduction.everything();
                }
                case SELF -> {
                    // 仅本人不贡献任何部门。
                }
                case DEPT -> departments.addAll(userDepts);
                case DEPT_AND_CHILD -> departments.addAll(withDescendants(userDepts, childrenOf));
                case CUSTOM_DEPT ->
                    departments.addAll(
                            scope.includeChild() ? withDescendants(scope.deptIds(), childrenOf) : scope.deptIds());
            }
        }
        return new Reduction(false, departments);
    }

    /** 给定部门及其全部下级；沿用访问标记，部门树出现环时也会终止。 */
    static Set<String> withDescendants(Set<String> roots, Map<String, List<String>> childrenOf) {
        Set<String> visited = new LinkedHashSet<>(roots);
        Deque<String> pending = new ArrayDeque<>(roots);
        while (!pending.isEmpty()) {
            for (String child : childrenOf.getOrDefault(pending.poll(), List.of())) {
                if (visited.add(child)) {
                    pending.add(child);
                }
            }
        }
        return visited;
    }
}
