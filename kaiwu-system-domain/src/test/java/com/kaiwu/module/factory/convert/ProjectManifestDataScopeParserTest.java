package com.kaiwu.module.factory.convert;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.factory.model.ProjectManifest;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** {@code data-scopes.yml} 的解析规则（docs/DATA_SCOPE.md §2）。 */
class ProjectManifestDataScopeParserTest {

    private final ProjectManifestParser parser = new ProjectManifestParser();

    /** 只带 data-scopes.yml 解析清单。 */
    private ProjectManifest parse(String yaml) {
        return parser.parse(Map.of("data-scopes.yml", yaml));
    }

    /** 断言 data-scopes.yml 被拒绝，且错误信息指向该文件并包含给定的原因片段。 */
    private void assertRejected(String yaml, String reasonFragment) {
        assertThatThrownBy(() -> parse(yaml))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.getMessage())
                        .contains("data-scopes.yml")
                        .contains(reasonFragment));
    }

    /** 解析资源时补齐默认归属列名，允许范围按枚举顺序输出；豁免项只用于业务仓门禁，平台不保存。 */
    @Test
    void parsesResourcesWithDefaultsAndDropsExemptions() {
        ProjectManifest manifest = parse(
                """
                resources:
                  - code: crm:customer
                    name: 客户
                    table: crm_customer
                    allowedScopes: [CUSTOM_DEPT, SELF, ALL]
                  - code: crm:followup
                    name: 跟进记录
                    table: crm_followup
                    ownerUserColumn: owner_id
                    ownerDeptColumn: dept_id
                    allowedScopes: [SELF]
                exempt:
                  - { table: crm_industry, reason: 行业字典，全员共享 }
                """);

        assertThat(manifest.dataResources()).hasSize(2);
        ProjectManifest.DataResource customer = manifest.dataResources().get(0);
        assertThat(customer.code()).isEqualTo("crm:customer");
        assertThat(customer.ownerUserColumn()).isEqualTo("owner_user_id");
        assertThat(customer.ownerDeptColumn()).isEqualTo("owner_dept_id");
        // 允许范围按枚举顺序输出，与书写顺序无关。
        assertThat(customer.allowedScopes()).containsExactly("ALL", "SELF", "CUSTOM_DEPT");
        assertThat(manifest.dataResources().get(1).ownerUserColumn()).isEqualTo("owner_id");
    }

    /** 没有文件、空文件或只有豁免项都表示没有声明任何受控资源。 */
    @Test
    void anEmptyOrMissingFileDeclaresNothing() {
        assertThat(parser.parse(Map.of()).dataResources()).isEmpty();
        assertThat(parse("").dataResources()).isEmpty();
        assertThat(parse("exempt:\n  - { table: crm_industry, reason: 字典 }\n").dataResources())
                .isEmpty();
    }

    /** 清单里出现默认范围等授权字段时给出专门提示：授权不随代码下发，只能在角色页配置。 */
    @Test
    void grantFieldsGetADedicatedMessageBecauseAuthorizationDoesNotTravelWithCode() {
        for (String field : new String[] {"defaultScope", "defaultScopes", "roles", "grants", "scope", "scopes"}) {
            assertRejected(
                    """
                    resources:
                      - code: crm:customer
                        name: 客户
                        table: crm_customer
                        allowedScopes: [SELF]
                        %s: DEPT
                    """
                            .formatted(field),
                    "授权不随代码下发");
        }
    }

    /** 未知字段和未知顶层键一律报错而不是静默忽略，避免拼写错误让约束悄悄失效。 */
    @Test
    void unknownFieldsAndTopLevelKeysAreRejectedInsteadOfIgnored() {
        assertRejected(
                """
                resources:
                  - { code: 'crm:customer', name: 客户, table: crm_customer, allowedScopes: [SELF], colour: red }
                """,
                "不支持的字段 colour");
        assertRejected("resources: []\nextra: 1\n", "不支持的顶层字段 extra");
        assertRejected("- code: crm:customer\n", "顶层必须是对象");
    }

    /** 允许范围必须非空、取值合法、不重复且包含 SELF，因为未配置的角色固定为仅本人。 */
    @Test
    void allowedScopesMustBeValidDistinctAndContainSelf() {
        String base = "resources:\n  - { code: 'crm:customer', name: 客户, table: crm_customer, allowedScopes: %s }\n";
        assertRejected(base.formatted("[ALL, DEPT]"), "必须包含 SELF");
        assertRejected(base.formatted("[SELF, ORG]"), "无效范围类型");
        assertRejected(base.formatted("[SELF, self]"), "无效范围类型");
        assertRejected(base.formatted("[SELF, SELF]"), "重复项");
        assertRejected(base.formatted("[]"), "非空列表");
        assertRejected("resources:\n  - { code: 'crm:customer', name: 客户, table: crm_customer }\n", "非空列表");
    }

    /** 资源码、表名、列名限制为安全字符集，业务服务据此拼接 SQL 标识符时不会被注入。 */
    @Test
    void identifiersAreRestrictedSoTheyCanBeUsedInSqlSafely() {
        String base = "resources:\n  - { code: '%s', name: 客户, table: %s, allowedScopes: [SELF] }\n";
        assertRejected(base.formatted("Crm:Customer", "crm_customer"), "code 格式");
        assertRejected(base.formatted("crm-customer", "crm_customer"), "code 格式");
        assertRejected(base.formatted("crm:customer", "crm customer"), "表名或列名");
        assertRejected(base.formatted("crm:customer", "crm_customer;drop"), "表名或列名");
        assertRejected(base.formatted("crm:customer", "1crm"), "表名或列名");
        assertRejected(
                "resources:\n  - { code: 'crm:customer', name: 客户, table: t, ownerUserColumn: a, ownerDeptColumn: a,"
                        + " allowedScopes: [SELF] }\n",
                "不能相同");
    }

    /** 同一份清单里资源码或表名重复会被拒绝。 */
    @Test
    void duplicateCodesAndTablesAreRejected() {
        assertRejected(
                """
                resources:
                  - { code: 'crm:customer', name: 客户, table: crm_a, allowedScopes: [SELF] }
                  - { code: 'crm:customer', name: 客户2, table: crm_b, allowedScopes: [SELF] }
                """,
                "资源码重复");
        assertRejected(
                """
                resources:
                  - { code: 'crm:customer', name: 客户, table: crm_a, allowedScopes: [SELF] }
                  - { code: 'crm:followup', name: 跟进, table: crm_a, allowedScopes: [SELF] }
                """,
                "表名重复");
    }

    /** 豁免项必须写明理由，不能与受控表重叠，也不能重复或带多余字段。 */
    @Test
    void exemptionsNeedAReasonAndCannotOverlapControlledTables() {
        assertRejected("exempt:\n  - { table: crm_industry }\n", "缺少 reason");
        assertRejected("exempt:\n  - { table: crm_industry, reason: '' }\n", "缺少 reason");
        assertRejected(
                """
                resources:
                  - { code: 'crm:customer', name: 客户, table: crm_customer, allowedScopes: [SELF] }
                exempt:
                  - { table: crm_customer, reason: 误写 }
                """,
                "不能同时豁免");
        assertRejected("exempt:\n  - { table: crm_a, reason: x }\n  - { table: crm_a, reason: y }\n", "豁免表重复");
        assertRejected("exempt:\n  - { table: crm_a, reason: x, note: y }\n", "不支持的字段 note");
    }

    /** data-scopes.yml 已加入受支持的清单文件名，拼写相近的其它文件名仍被拒绝。 */
    @Test
    void theNewFileIsAcceptedAlongsideTheOthersAndOtherFileNamesStillFail() {
        assertThat(ProjectManifestParser.FILES).contains("data-scopes.yml");
        assertThatThrownBy(() -> parser.parse(Map.of("data-scope.yml", "resources: []")))
                .isInstanceOf(ApiException.class);
    }
    // ---- roles.yml 的 dataScopes ----

    /** 解析带有给定 dataScopes 片段的最小 roles.yml。 */
    private ProjectManifest parseRole(String dataScopesYaml) {
        return parser.parse(Map.of("roles.yml", "- roleCode: sales-manager\n  name: 销售经理\n" + dataScopesYaml));
    }

    /** 断言 roles.yml 里的 dataScopes 被拒绝，且错误信息指向该文件并包含给定的原因片段。 */
    private void assertRoleRejected(String dataScopesYaml, String reasonFragment) {
        assertThatThrownBy(() -> parseRole(dataScopesYaml))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.getMessage())
                        .contains("roles.yml")
                        .contains(reasonFragment));
    }

    /** 角色的数据范围按资源解析，指定部门使用部门编码而不是 ID。 */
    @Test
    void roleDataScopesAreParsedWithDepartmentCodes() {
        ProjectManifest manifest = parseRole(
                """
                  dataScopes:
                    - { resource: 'crm:customer', scope: DEPT_AND_CHILD }
                    - { resource: 'crm:contract', scope: CUSTOM_DEPT, depts: [SALES-EAST, SALES-NORTH], includeChild: true }
                    - { resource: 'crm:followup', scope: SELF }
                """);

        assertThat(manifest.roles().get(0).dataScopes())
                .containsExactly(
                        new ProjectManifest.RoleDataScope("crm:customer", "DEPT_AND_CHILD", false, java.util.List.of()),
                        new ProjectManifest.RoleDataScope(
                                "crm:contract", "CUSTOM_DEPT", true, java.util.List.of("SALES-EAST", "SALES-NORTH")),
                        new ProjectManifest.RoleDataScope("crm:followup", "SELF", false, java.util.List.of()));
    }

    /** 没有 dataScopes 的角色解析结果与引入数据范围之前一致。 */
    @Test
    void rolesWithoutDataScopesParseAsBefore() {
        assertThat(parseRole("").roles().get(0).dataScopes()).isEmpty();
    }

    /** 角色数据范围逐项严格校验：类型、资源码、重复、部门与 includeChild 的组合以及布尔取值。 */
    @Test
    void roleDataScopesAreValidatedStrictly() {
        assertRoleRejected("  dataScopes: x\n", "dataScopes 必须是列表");
        assertRoleRejected("  dataScopes:\n    - { resource: 'crm:customer', scope: ORG }\n", "scope 取值无效");
        assertRoleRejected("  dataScopes:\n    - { resource: 'crm:customer', scope: dept }\n", "scope 取值无效");
        assertRoleRejected("  dataScopes:\n    - { resource: 'Bad', scope: SELF }\n", "resource 格式");
        assertRoleRejected("  dataScopes:\n    - { scope: SELF }\n", "缺少 resource");
        assertRoleRejected(
                "  dataScopes:\n    - { resource: 'crm:customer', scope: SELF }\n"
                        + "    - { resource: 'crm:customer', scope: DEPT }\n",
                "资源重复");
        assertRoleRejected(
                "  dataScopes:\n    - { resource: 'crm:customer', scope: DEPT, depts: [A] }\n", "只有 CUSTOM_DEPT");
        assertRoleRejected(
                "  dataScopes:\n    - { resource: 'crm:customer', scope: DEPT, includeChild: true }\n",
                "只有 CUSTOM_DEPT");
        assertRoleRejected("  dataScopes:\n    - { resource: 'crm:customer', scope: CUSTOM_DEPT }\n", "至少需要一个部门编码");
        assertRoleRejected(
                "  dataScopes:\n    - { resource: 'crm:customer', scope: CUSTOM_DEPT, depts: [A], includeChild: 'true' }\n",
                "includeChild 必须是 true 或 false");
        assertRoleRejected(
                "  dataScopes:\n    - { resource: 'crm:customer', scope: SELF, colour: red }\n", "不支持的字段 colour");
    }

    /** 内置 project-admin 仍不由移交包管理，带数据范围也不例外。 */
    @Test
    void theBuiltInAdminRoleStillCannotCarryDataScopes() {
        assertThatThrownBy(() -> parser.parse(Map.of(
                        "roles.yml",
                        "- roleCode: project-admin\n  name: 管理员\n  dataScopes:\n"
                                + "    - { resource: 'crm:customer', scope: ALL }\n")))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.getMessage())
                        .contains("project-admin"));
    }
}
