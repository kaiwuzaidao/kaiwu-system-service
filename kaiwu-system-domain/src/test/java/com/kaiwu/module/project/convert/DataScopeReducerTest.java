package com.kaiwu.module.project.convert;

import static org.assertj.core.api.Assertions.assertThat;

import com.kaiwu.module.project.convert.DataScopeReducer.Reduction;
import com.kaiwu.module.project.convert.DataScopeReducer.RoleScope;
import com.kaiwu.module.project.model.DataScopeType;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;

/** 覆盖 docs/DATA_SCOPE.md §3.4 真值表：五种类型、多角色并集、未配置与无部门退化。 */
class DataScopeReducerTest {

    /** A 下有 A1、A2，A1 下有 A11；X 下有 X1。 */
    private static final Map<String, List<String>> TREE = Map.of(
            "10", List.of("11", "12"),
            "11", List.of("111"),
            "20", List.of("21"));

    /** 构造一条指定部门配置。 */
    private static RoleScope custom(boolean includeChild, String... depts) {
        return new RoleScope(DataScopeType.CUSTOM_DEPT, includeChild, Set.of(depts));
    }

    /** 用测试部门树归约给定的角色配置。 */
    private static Reduction reduce(Set<String> userDepts, RoleScope... scopes) {
        return DataScopeReducer.reduce(List.of(scopes), userDepts, TREE);
    }

    /** 没有任何配置时只有本人。 */
    @Test
    void noConfigurationMeansSelfOnly() {
        assertThat(reduce(Set.of("10"))).isEqualTo(Reduction.selfOnly());
    }

    /** 仅本人不贡献任何部门。 */
    @Test
    void selfContributesNoDepartments() {
        assertThat(reduce(Set.of("10"), RoleScope.of(DataScopeType.SELF))).isEqualTo(Reduction.selfOnly());
    }

    /** 本部门取用户的全部所属部门。 */
    @Test
    void deptUsesEveryDepartmentTheUserBelongsTo() {
        assertThat(reduce(Set.of("10"), RoleScope.of(DataScopeType.DEPT)).deptIds())
                .containsExactlyInAnyOrder("10");
        assertThat(reduce(Set.of("10", "20"), RoleScope.of(DataScopeType.DEPT)).deptIds())
                .containsExactlyInAnyOrder("10", "20");
    }

    /** 用户没有所属部门时，按部门的范围退化为仅本人。 */
    @Test
    void deptWithoutAnyDepartmentDegradesToSelf() {
        assertThat(reduce(Set.of(), RoleScope.of(DataScopeType.DEPT))).isEqualTo(Reduction.selfOnly());
        assertThat(reduce(Set.of(), RoleScope.of(DataScopeType.DEPT_AND_CHILD))).isEqualTo(Reduction.selfOnly());
    }

    /** 本部门及下级展开整棵子树。 */
    @Test
    void deptAndChildExpandsTheWholeSubtree() {
        assertThat(reduce(Set.of("10"), RoleScope.of(DataScopeType.DEPT_AND_CHILD))
                        .deptIds())
                .containsExactlyInAnyOrder("10", "11", "12", "111");
    }

    /** 指定部门按 includeChild 决定是否展开下级。 */
    @Test
    void customDeptHonoursIncludeChild() {
        assertThat(reduce(Set.of("10"), custom(false, "20")).deptIds()).containsExactlyInAnyOrder("20");
        assertThat(reduce(Set.of("10"), custom(true, "20")).deptIds()).containsExactlyInAnyOrder("20", "21");
    }

    /** 任一角色为全部，则结果为全部。 */
    @Test
    void allWinsOverEveryOtherRole() {
        assertThat(reduce(Set.of("10"), RoleScope.of(DataScopeType.DEPT), RoleScope.of(DataScopeType.ALL))
                        .all())
                .isTrue();
        assertThat(reduce(Set.of("10"), RoleScope.of(DataScopeType.ALL))).isEqualTo(Reduction.everything());
    }

    /** 多个角色的部门取并集。 */
    @Test
    void multipleRolesUnionTheirDepartments() {
        assertThat(reduce(Set.of("10"), RoleScope.of(DataScopeType.DEPT), custom(false, "20"))
                        .deptIds())
                .containsExactlyInAnyOrder("10", "20");
    }

    /** 未配置的角色只贡献仅本人，不会缩小其它角色的范围。 */
    @Test
    void anUnconfiguredSecondRoleDoesNotShrinkTheFirst() {
        // 没有显式配置的角色不出现在入参里，它只贡献仅本人。
        assertThat(reduce(Set.of("10"), RoleScope.of(DataScopeType.DEPT)).deptIds())
                .containsExactlyInAnyOrder("10");
    }

    /** 部门树出现环时展开也会终止。 */
    @Test
    void aCycleInTheDepartmentTreeTerminates() {
        Map<String, List<String>> cyclic = Map.of("1", List.of("2"), "2", List.of("1"));
        Reduction result =
                DataScopeReducer.reduce(List.of(RoleScope.of(DataScopeType.DEPT_AND_CHILD)), Set.of("1"), cyclic);
        assertThat(result.deptIds()).containsExactlyInAnyOrder("1", "2");
    }

    /** 结果为全部时丢弃部门集合，使相等性只取决于语义。 */
    @Test
    void allDropsDepartmentsSoEqualityIsSemantic() {
        assertThat(new Reduction(true, Set.of("1"))).isEqualTo(Reduction.everything());
    }
}
