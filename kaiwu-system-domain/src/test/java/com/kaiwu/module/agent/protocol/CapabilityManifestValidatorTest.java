package com.kaiwu.module.agent.protocol;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.kaiwu.port.agent.protocol.ConfirmationMode;
import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.function.Consumer;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

class CapabilityManifestValidatorTest {
    private static final Set<String> REGISTERED_PERMISSIONS = Set.of("crm:record:list", "order:order:list");
    private final CapabilityManifestValidator validator = new CapabilityManifestValidator();

    @Test
    void acceptsCredentialBoundReadOnlyManifestWithoutGrantingTrust() {
        CapabilityManifest manifest = manifest(f -> {});
        assertThat(validator.validate(manifest, "crm", REGISTERED_PERMISSIONS)).isSameAs(manifest);
        // Registration input has no verifiedReadOnly flag. Validation does not grant execution approval.
        assertThatCode(() -> validator.validate(
                        manifest(f -> {
                            f.readOnly = false;
                            f.idempotent = true;
                            f.confirmation = ConfirmationMode.REQUIRED;
                        }),
                        "crm",
                        REGISTERED_PERMISSIONS))
                .doesNotThrowAnyException();
    }

    @Test
    void acceptsBoundedStringListButNotUnboundedOrDefaultedLists() {
        assertThatCode(() -> validator.validate(
                        manifest(f -> f.params = Map.of("ids", ParamSpec.stringList(true, 0, 20, 19))),
                        "crm",
                        REGISTERED_PERMISSIONS))
                .doesNotThrowAnyException();
        assertThatThrownBy(() -> ParamSpec.stringList(true, 0, 101, 19)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(
                        () -> new ParamSpec(ParamType.STRING_LIST, true, 0, 20, 19, null, null, java.util.List.of("1")))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void rejectsMissingManifest() {
        assertThatThrownBy(() -> validator.validate(null, "crm", REGISTERED_PERMISSIONS))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = {"other", "system", " ", "crm-other"})
    void requiresAuthenticatedProjectBinding(String authenticatedProject) {
        assertThatThrownBy(() -> validator.validate(manifest(f -> {}), authenticatedProject, REGISTERED_PERMISSIONS))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void rejectsForgedProjectEvenWhenCodeAndPermissionAreConsistent() {
        rejects(
                f -> {
                    f.projectCode = "other";
                    f.code = "other.record.search";
                    f.permission = "other:record:list";
                },
                "凭据");
    }

    @Test
    void rejectsRemoteSystemRegistration() {
        CapabilityManifest manifest = manifest(f -> {
            f.projectCode = "system";
            f.code = "system.project.list";
            f.permission = "system:project:list";
        });
        assertThatThrownBy(() -> validator.validate(manifest, "system", Set.of("system:project:list")))
                .hasMessageContaining("system");
    }

    @ParameterizedTest
    @ValueSource(
            strings = {
                "system.project.list",
                "other.record.search",
                "crm-other.record.search",
                "crm..list",
                "crm.record/list"
            })
    void rejectsForeignAndMalformedCapabilityCodes(String code) {
        rejects(f -> f.code = code, "能力码");
    }

    @Test
    void acceptsExistingMaximumLengthProjectCode() {
        String project = "p".repeat(64);
        assertThatCode(() -> validator.validate(
                        manifest(f -> {
                            f.projectCode = project;
                            f.code = project + ".record.search";
                            f.permission = project + ":record:list";
                        }),
                        project,
                        Set.of(project + ":record:list")))
                .doesNotThrowAnyException();
    }

    @Test
    void rejectsForeignPermissionAndOversizedMetadata() {
        rejects(f -> f.permission = "system:project:list", "权限");
        rejects(f -> f.code = "crm." + "a".repeat(160), "能力码");
        rejects(f -> f.version = "1".repeat(17), "version");
        rejects(f -> f.description = "x".repeat(201), "description");
        rejects(f -> f.dataScope = null, "dataScope");
    }

    @Test
    void acceptsGeneratedModulePermissionOnlyWhenRegisteredInTargetProject() {
        CapabilityManifest generated = manifest(f -> f.permission = "order:order:list");
        assertThatCode(() -> validator.validate(generated, "crm", REGISTERED_PERMISSIONS))
                .doesNotThrowAnyException();
        assertThatThrownBy(() -> validator.validate(generated, "crm", Set.of())).hasMessageContaining("权限码未在目标项目登记");
        assertThatThrownBy(() -> validator.validate(generated, "crm", null)).hasMessageContaining("权限码未在目标项目登记");
    }

    @Test
    void rejectsMissingContractFieldsInsteadOfSupplyingDefaults() {
        rejects(f -> f.params = null, "params");
        rejects(f -> f.outboundFields = null, "outboundFields");
        rejects(f -> f.redact = null, "redact");
        rejects(f -> f.readOnly = null, "readOnly");
        rejects(f -> f.idempotent = null, "idempotent");
        rejects(f -> f.confirmation = null, "confirmation");
        rejects(f -> f.timeoutMs = null, "timeoutMs");
    }

    @Test
    void enforcesConfirmationAndReadOnlyIdempotency() {
        rejects(f -> f.readOnly = false, "确认");
        rejects(f -> f.confirmation = ConfirmationMode.REQUIRED, "NONE");
        rejects(f -> f.idempotent = false, "幂等");
        rejects(
                f -> {
                    f.readOnly = false;
                    f.idempotent = false;
                    f.confirmation = ConfirmationMode.REQUIRED;
                },
                "写能力必须声明幂等");
        assertThatCode(() -> validator.validate(
                        manifest(f -> {
                            f.readOnly = false;
                            f.confirmation = ConfirmationMode.STRONG;
                        }),
                        "crm",
                        REGISTERED_PERMISSIONS))
                .doesNotThrowAnyException();
    }

    @ParameterizedTest
    @ValueSource(
            strings = {
                "userId",
                "USER_ID",
                "tenantId",
                "roleCode",
                "projectId",
                "project_code",
                "sessionId",
                "actor",
                "operator",
                "permissions",
                "ownerUserId",
                "authorization",
                "accessToken",
                "backendUrl"
            })
    void rejectsModelSuppliedIdentityAndCredentials(String name) {
        rejects(f -> f.params = Map.of(name, ParamSpec.optionalString(100)), "参数");
    }

    @ParameterizedTest
    @ValueSource(strings = {"$.name", "item.name", "record[0]", "name/path", " ", "name-value"})
    void rejectsExpressionsAndPathsInFieldNames(String name) {
        rejects(f -> f.params = Map.of(name, ParamSpec.optionalString(100)), "参数");
        rejects(f -> f.outboundFields = Set.of(name), "outboundFields");
    }

    @ParameterizedTest
    @ValueSource(
            strings = {
                "backendUrl",
                "password",
                "access_token",
                "clientSecret",
                "private_key",
                "credential",
                "authorization"
            })
    void rejectsSensitiveModelOutputFields(String name) {
        rejects(f -> f.outboundFields = Set.of(name), "outboundFields");
    }

    @Test
    void rejectsUnlistedRedactionAndTooManyParameters() {
        rejects(f -> f.redact = Map.of("secret", RedactRule.MASK), "redact");
        Map<String, ParamSpec> params = new HashMap<>();
        for (int i = 0; i < 33; i++) params.put("field" + i, ParamSpec.optionalBool());
        rejects(f -> f.params = params, "参数数量");
        rejects(
                f -> f.outboundFields = java.util.stream.IntStream.range(0, 65)
                        .mapToObj(i -> "field" + i)
                        .collect(java.util.stream.Collectors.toSet()),
                "outboundFields");
    }

    @ParameterizedTest
    @ValueSource(ints = {-1, 0, 99, 10001, 60000})
    void rejectsUnsafeTimeout(int timeoutMs) {
        rejects(f -> f.timeoutMs = timeoutMs, "timeoutMs");
    }

    @Test
    void rejectsUnboundedAndContradictoryParameterSchemas() {
        rejectsParam(ParamSpec.optionalString(0));
        rejectsParam(ParamSpec.optionalString(4001));
        rejectsParam(ParamSpec.optionalVisibleProject());
        rejectsParam(ParamSpec.optionalEnum(Set.of()));
        rejectsParam(new ParamSpec(ParamType.INT, false, 50, 1, null, null, null, null));
        rejectsParam(new ParamSpec(ParamType.INT, false, null, null, null, null, null, null));
        rejectsParam(new ParamSpec(ParamType.BOOL, false, 1, 10, null, null, null, null));
        rejectsParam(new ParamSpec(ParamType.STRING, false, null, null, 10, Set.of("x"), null, null));
    }

    @Test
    void validatesDefaultsWithSameTypeAndRangeAsRuntimeInput() {
        rejectsParam(new ParamSpec(ParamType.INT, false, 1, 50, null, null, null, 51));
        rejectsParam(new ParamSpec(ParamType.INT, false, 1, 50, null, null, null, new BigDecimal("1.5")));
        rejectsParam(new ParamSpec(ParamType.INT, false, 1, 50, null, null, null, "20"));
        rejectsParam(new ParamSpec(ParamType.BOOL, false, null, null, null, null, null, "true"));
        rejectsParam(new ParamSpec(ParamType.STRING, false, null, null, 3, null, null, "long"));
        rejectsParam(new ParamSpec(ParamType.ENUM, false, null, null, null, Set.of("A"), null, "B"));
        rejectsParam(new ParamSpec(ParamType.DATETIME, false, null, null, null, null, null, "tomorrow"));
        rejectsParam(new ParamSpec(ParamType.STRING, false, null, null, 30, null, null, Map.of("x", "y")));
        assertThatCode(() -> validator.validate(
                        manifest(f -> f.params = Map.of(
                                "size", ParamSpec.pageSize(50, 20),
                                "enabled", ParamSpec.optionalBool(),
                                "status", ParamSpec.optionalEnum(Set.of("ACTIVE", "DISABLED")),
                                "since", ParamSpec.optionalDateTime())),
                        "crm",
                        REGISTERED_PERMISSIONS))
                .doesNotThrowAnyException();
    }

    @Test
    void snapshotsMutableCollectionsBeforeValidation() {
        Map<String, ParamSpec> params = new HashMap<>(Map.of("keyword", ParamSpec.optionalString(100)));
        CapabilityManifest manifest = manifest(f -> f.params = params);
        params.put("userId", ParamSpec.optionalString(20));
        assertThat(validator.validate(manifest, "crm", REGISTERED_PERMISSIONS).params())
                .doesNotContainKey("userId");
        assertThatThrownBy(() -> manifest.params().clear()).isInstanceOf(UnsupportedOperationException.class);
    }

    @Test
    void validatesActualJsonWireContractAndRejectsOmittedFlags() {
        tools.jackson.databind.ObjectMapper mapper = new tools.jackson.databind.ObjectMapper();
        String json = mapper.writeValueAsString(manifest(f -> {}));
        assertThatCode(() -> validator.validate(
                        mapper.readValue(json, CapabilityManifest.class), "crm", REGISTERED_PERMISSIONS))
                .doesNotThrowAnyException();
        for (String key : new String[] {"readOnly", "idempotent", "timeoutMs"}) {
            var node = (tools.jackson.databind.node.ObjectNode) mapper.readTree(json);
            node.remove(key);
            String missing = mapper.writeValueAsString(node);
            assertThatThrownBy(() -> validator.validate(
                            mapper.readValue(missing, CapabilityManifest.class), "crm", REGISTERED_PERMISSIONS))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining(key);
        }
    }

    private void rejectsParam(ParamSpec spec) {
        rejects(f -> f.params = Map.of("value", spec), "参数");
    }

    private void rejects(Consumer<Fixture> change, String message) {
        assertThatThrownBy(() -> validator.validate(manifest(change), "crm", REGISTERED_PERMISSIONS))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining(message);
    }

    private static CapabilityManifest manifest(Consumer<Fixture> change) {
        Fixture f = new Fixture();
        change.accept(f);
        return new CapabilityManifest(
                f.projectCode,
                f.code,
                f.version,
                f.description,
                f.permission,
                f.dataScope,
                f.params,
                f.outboundFields,
                f.redact,
                f.readOnly,
                f.idempotent,
                f.confirmation,
                f.timeoutMs);
    }

    private static class Fixture {
        String projectCode = "crm";
        String code = "crm.record.search";
        String version = "1";
        String description = "查询跟进记录";
        String permission = "crm:record:list";
        DataScope dataScope = DataScope.MEMBER_PROJECTS;
        Map<String, ParamSpec> params = Map.of("keyword", ParamSpec.optionalString(100));
        Set<String> outboundFields = Set.of("id", "title");
        Map<String, RedactRule> redact = Map.of();
        Boolean readOnly = true;
        Boolean idempotent = true;
        ConfirmationMode confirmation = ConfirmationMode.NONE;
        Integer timeoutMs = 3000;
    }

    // ---- ADR 0044：ROLE_SCOPED 与受控资源 ----

    private static final Set<String> CONTROLLED = Set.of("crm:record");

    /** ROLE_SCOPED 只在权限前缀对应项目已启用的受控资源时才被接受，否则声明的是无法执行的策略。 */
    @Test
    void roleScopedIsAcceptedOnlyWhenThePermissionBelongsToAControlledResource() {
        CapabilityManifest scoped = manifest(f -> f.dataScope = DataScope.ROLE_SCOPED);

        assertThatCode(() -> validator.validate(scoped, "crm", REGISTERED_PERMISSIONS, CONTROLLED))
                .doesNotThrowAnyException();
        assertThatThrownBy(() -> validator.validate(scoped, "crm", REGISTERED_PERMISSIONS, Set.of()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("ROLE_SCOPED");
        assertThatThrownBy(() -> validator.validate(scoped, "crm", REGISTERED_PERMISSIONS, Set.of("crm:other")))
                .isInstanceOf(IllegalArgumentException.class);
    }

    /** 对受控资源声明 ALL 会被拒绝，非受控资源不受影响；前缀必须整段相同，crm:rec 不等于 crm:record。 */
    @Test
    void allIsRejectedOnAControlledResourceButStillAllowedElsewhere() {
        CapabilityManifest all = manifest(f -> f.dataScope = DataScope.ALL);

        assertThatThrownBy(() -> validator.validate(all, "crm", REGISTERED_PERMISSIONS, CONTROLLED))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("ROLE_SCOPED");
        assertThatCode(() -> validator.validate(all, "crm", REGISTERED_PERMISSIONS, Set.of()))
                .doesNotThrowAnyException();
        assertThatCode(() -> validator.validate(all, "crm", REGISTERED_PERMISSIONS, Set.of("crm:rec")))
                .as("前缀必须整段相同，crm:rec 不是 crm:record")
                .doesNotThrowAnyException();
    }

    /** SELF 与 MEMBER_PROJECTS 比 ALL 更窄，即使对应受控资源也照常通过。 */
    @Test
    void narrowerScopesAreNotAffectedByControlledResources() {
        for (DataScope scope : new DataScope[] {DataScope.SELF, DataScope.MEMBER_PROJECTS}) {
            CapabilityManifest manifest = manifest(f -> f.dataScope = scope);
            assertThatCode(() -> validator.validate(manifest, "crm", REGISTERED_PERMISSIONS, CONTROLLED))
                    .doesNotThrowAnyException();
        }
    }

    /** 三参重载等价于没有受控资源，既有调用方的行为不变。 */
    @Test
    void theThreeArgumentOverloadKeepsTheOldBehaviourWithNoControlledResources() {
        assertThatCode(() ->
                        validator.validate(manifest(f -> f.dataScope = DataScope.ALL), "crm", REGISTERED_PERMISSIONS))
                .doesNotThrowAnyException();
        assertThatThrownBy(() -> validator.validate(
                        manifest(f -> f.dataScope = DataScope.ROLE_SCOPED), "crm", REGISTERED_PERMISSIONS))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
