package com.kaiwu.module.projecthealth;

import static org.assertj.core.api.Assertions.assertThat;

import com.kaiwu.module.projecthealth.ProjectHealthEvaluator.RepositorySources;
import com.kaiwu.module.projecthealth.vo.ProjectHealthView.CheckView;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

class ProjectHealthEvaluatorTest {

    private static final String TEMPLATE = "kaiwu-project-v5";
    private static final String STARTER = "0.1.0-SNAPSHOT";

    private final ProjectHealthEvaluator evaluator = new ProjectHealthEvaluator(new ObjectMapper());

    private static final String HEALTHY_CI =
            """
            script:
              - bash scripts/check-permission-seed.sh
              - bash scripts/check-test-baseline.sh
              - sh scripts/check-constraints.sh
              - mvn --batch-mode verify
            secrets:
              image: ghcr.io/gitleaks/gitleaks:v8.28.0
            dependencies:
              script: trivy fs --format cyclonedx .
            image-vulnerabilities:
              script: trivy image "$KAIWU_IMAGE_REF"
            """;
    private static final String HEALTHY_PACKAGE =
            """
            {"scripts":{"check:dict":"node scripts/check-dict-consistency.mjs",
            "check:perm":"node scripts/check-permission-consistency.mjs",
            "check:constraints":"sh scripts/check-constraints.sh"}}
            """;
    private static final String HEALTHY_POM =
            "<kaiwu-system-starter.version>0.1.0-SNAPSHOT</kaiwu-system-starter.version>";

    private static String manifest(String templateVersion) {
        return "{\"templateVersion\":\"" + templateVersion + "\",\"modules\":[]}";
    }

    private RepositorySources healthy() {
        return new RepositorySources(
                true,
                true,
                Optional.of(manifest(TEMPLATE)),
                Optional.of(HEALTHY_CI),
                Optional.of(HEALTHY_POM),
                Optional.of(HEALTHY_PACKAGE));
    }

    private String verdictOf(List<CheckView> checks, String code) {
        return checks.stream()
                .filter(check -> code.equals(check.code()))
                .findFirst()
                .orElseThrow()
                .verdict();
    }

    @Test
    void intactContractPasses() {
        List<CheckView> checks = evaluator.evaluate(healthy(), TEMPLATE, STARTER);

        assertThat(checks).extracting(CheckView::verdict).containsOnly("PASS");
        assertThat(evaluator.summarize(checks)).isEqualTo("PASS");
    }

    @Test
    void removedPermissionGateFails() {
        RepositorySources sources = new RepositorySources(
                true,
                true,
                Optional.of(manifest(TEMPLATE)),
                Optional.of(
                        "script:\n  - sh scripts/check-constraints.sh\n  - mvn --batch-mode verify\nsecrets:\n  image: gitleaks\n"),
                Optional.of(HEALTHY_POM),
                Optional.of(HEALTHY_PACKAGE));

        List<CheckView> checks = evaluator.evaluate(sources, TEMPLATE, STARTER);

        assertThat(verdictOf(checks, "backend.gate")).isEqualTo("FAIL");
        assertThat(evaluator.summarize(checks)).isEqualTo("FAIL");
    }

    @Test
    void removedTestBaselineGateOnlyWarns() {
        RepositorySources sources = new RepositorySources(
                true,
                true,
                Optional.of(manifest(TEMPLATE)),
                Optional.of(
                        "script:\n  - bash scripts/check-permission-seed.sh\n  - sh scripts/check-constraints.sh\nsecrets:\n  image: gitleaks\ndependencies:\n  script: trivy fs --format cyclonedx .\nimage:\n  script: trivy image $KAIWU_IMAGE_REF\n"),
                Optional.of(HEALTHY_POM),
                Optional.of(HEALTHY_PACKAGE));

        List<CheckView> checks = evaluator.evaluate(sources, TEMPLATE, STARTER);

        assertThat(verdictOf(checks, "backend.gate")).isEqualTo("WARN");
        assertThat(evaluator.summarize(checks)).isEqualTo("WARN");
    }

    @Test
    void deletedManifestFails() {
        RepositorySources sources = new RepositorySources(
                true,
                true,
                Optional.empty(),
                Optional.of(HEALTHY_CI),
                Optional.of(HEALTHY_POM),
                Optional.of(HEALTHY_PACKAGE));

        List<CheckView> checks = evaluator.evaluate(sources, TEMPLATE, STARTER);

        assertThat(verdictOf(checks, "contract.manifest")).isEqualTo("FAIL");
    }

    @Test
    void removedSupplyChainGateFails() {
        RepositorySources sources = new RepositorySources(
                true,
                true,
                Optional.of(manifest(TEMPLATE)),
                Optional.of(
                        "script:\n  - bash scripts/check-permission-seed.sh\n  - bash scripts/check-test-baseline.sh\n  - sh scripts/check-constraints.sh\nsecrets:\n  image: gitleaks\n"),
                Optional.of(HEALTHY_POM),
                Optional.of(HEALTHY_PACKAGE));

        List<CheckView> checks = evaluator.evaluate(sources, TEMPLATE, STARTER);

        assertThat(verdictOf(checks, "backend.gate")).isEqualTo("FAIL");
    }

    @Test
    void missingFrontendPermissionScriptFails() {
        RepositorySources sources = new RepositorySources(
                true,
                true,
                Optional.of(manifest(TEMPLATE)),
                Optional.of(HEALTHY_CI),
                Optional.of(HEALTHY_POM),
                Optional.of("{\"scripts\":{\"check:dict\":\"node x.mjs\"}}"));

        List<CheckView> checks = evaluator.evaluate(sources, TEMPLATE, STARTER);

        assertThat(verdictOf(checks, "frontend.gate")).isEqualTo("FAIL");
    }

    /** 版本落后只报 WARN：平台无权要求业务项目跟随升级（ADR 0012 第 5 节）。 */
    @Test
    void staleTemplateAndStarterOnlyWarn() {
        RepositorySources sources = new RepositorySources(
                true,
                true,
                Optional.of(manifest("kaiwu-project-v2")),
                Optional.of(HEALTHY_CI),
                Optional.of("<kaiwu-system-starter.version>0.0.9</kaiwu-system-starter.version>"),
                Optional.of(HEALTHY_PACKAGE));

        List<CheckView> checks = evaluator.evaluate(sources, TEMPLATE, STARTER);

        assertThat(verdictOf(checks, "version.template")).isEqualTo("WARN");
        assertThat(verdictOf(checks, "version.starter")).isEqualTo("WARN");
        assertThat(evaluator.summarize(checks)).isEqualTo("WARN");
    }

    /**
     * 仓库不可读时必须是 UNKNOWN 而不是 FAIL。
     * 只下载 ZIP 自行托管的项目平台本来就看不到，一次网络抖动也不该给项目扣上不合格的帽子。
     */
    @Test
    void unreadableRepositoriesReportUnknownNotFailure() {
        RepositorySources sources = new RepositorySources(
                false, false, Optional.empty(), Optional.empty(), Optional.empty(), Optional.empty());

        List<CheckView> checks = evaluator.evaluate(sources, TEMPLATE, STARTER);

        assertThat(checks).extracting(CheckView::verdict).containsOnly("UNKNOWN");
        assertThat(evaluator.summarize(checks)).isEqualTo("UNKNOWN");
    }

    @Test
    void corruptManifestFailsWithoutLeakingContent() {
        RepositorySources sources = new RepositorySources(
                true,
                true,
                Optional.of("{not json"),
                Optional.of(HEALTHY_CI),
                Optional.of(HEALTHY_POM),
                Optional.of(HEALTHY_PACKAGE));

        List<CheckView> checks = evaluator.evaluate(sources, TEMPLATE, STARTER);

        assertThat(verdictOf(checks, "contract.manifest")).isEqualTo("FAIL");
        // 结论里不得出现被读取的文件内容（ADR 0012 第 2 节）。
        assertThat(checks).allSatisfy(check -> assertThat(check.detail()).doesNotContain("not json"));
    }
}
