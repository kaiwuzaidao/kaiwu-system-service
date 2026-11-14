package com.kaiwu.module.agent.protocol;

import static org.assertj.core.api.Assertions.*;

import java.util.*;
import org.junit.jupiter.api.Test;

class AgentOutputProtocolTest {
    @Test
    void sharedDigestBindsOutputLabelsFormatsAndOrder() throws Exception {
        byte[] raw;
        try (var in = getClass().getResourceAsStream("/agent-registration-output-v3.json")) {
            raw = in.readAllBytes();
        }
        var manifest = new AgentManifestCodec().decode(raw);
        assertThat(AgentManifestCodec.digest(new AgentManifestCodec().canonical(manifest)))
                .isEqualTo("2a788d17ed0ddb1ed57fe75b054e93cc069af626119e6e84c2319aa03d14bcb5");
        assertThat(manifest.outputView().fields())
                .extracting(OutputViewSpec.Field::name)
                .containsExactly("id", "title");
        String original = new String(raw, java.nio.charset.StandardCharsets.UTF_8);
        for (String change : List.of(
                original.replace("编号", "标识"),
                original.replace("TEXT", "DATETIME"),
                original.replace("\"name\": \"id\"", "\"name\": \"temp\"")
                        .replace("\"name\": \"title\"", "\"name\": \"id\"")
                        .replace("\"name\": \"temp\"", "\"name\": \"title\""))) {
            raw = change.getBytes(java.nio.charset.StandardCharsets.UTF_8);
            manifest = new AgentManifestCodec().decode(raw);
            assertThat(AgentManifestCodec.digest(new AgentManifestCodec().canonical(manifest)))
                    .isNotEqualTo("2a788d17ed0ddb1ed57fe75b054e93cc069af626119e6e84c2319aa03d14bcb5");
        }
    }

    @Test
    void rejectsUnsafeOrUnapprovedOutputFieldsAndFormats() {
        var good = new OutputViewSpec.Field("id", "编号", OutputViewSpec.Format.TEXT, null);
        for (var view : List.of(
                new OutputViewSpec("标题", List.of()),
                new OutputViewSpec("标题", List.of(good, good)),
                new OutputViewSpec(
                        "标题", List.of(new OutputViewSpec.Field("secret", "秘密", OutputViewSpec.Format.TEXT, null))),
                new OutputViewSpec(
                        "标题",
                        List.of(new OutputViewSpec.Field("sourceProjectId", "来源", OutputViewSpec.Format.TEXT, null))),
                new OutputViewSpec("标题", List.of(new OutputViewSpec.Field("id", "编号", null, null))),
                new OutputViewSpec(
                        "标题",
                        List.of(new OutputViewSpec.Field(
                                "id", "编号", OutputViewSpec.Format.DICTIONARY, "https://evil.test"))),
                new OutputViewSpec(
                        "标题",
                        List.of(new OutputViewSpec.Field(
                                "id", "编号", OutputViewSpec.Format.TEXT, "common.boolean_enabled"))),
                new OutputViewSpec("x".repeat(101), List.of(good)),
                new OutputViewSpec(
                        "标题", List.of(new OutputViewSpec.Field("id", "a\nb", OutputViewSpec.Format.TEXT, null))))) {
            assertThatThrownBy(() -> view.validate(Set.of("id", "sourceProjectId")))
                    .isInstanceOf(IllegalArgumentException.class);
        }
        new OutputViewSpec(
                        "标题",
                        List.of(new OutputViewSpec.Field(
                                "id", "编号", OutputViewSpec.Format.DICTIONARY, "agent.crm.record_status")))
                .validate(Set.of("id"));
    }

    @Test
    void navigationRejectsCrossProjectAndRedactedBindingsAndUnboundedPaging() {
        var fields = List.of(new OutputViewSpec.Field("id", "编号", OutputViewSpec.Format.TEXT, null));
        var view = new OutputViewSpec(
                "列表", fields, null, new OutputViewSpec.Detail("详情", "other.item.detail", "id", "id"));
        assertThatThrownBy(() -> view.validateNavigation("demo", Map.of(), null, true, Map.of()))
                .isInstanceOf(IllegalArgumentException.class);
        var own =
                new OutputViewSpec("列表", fields, null, new OutputViewSpec.Detail("详情", "demo.item.detail", "id", "id"));
        assertThatThrownBy(() -> own.validateNavigation("demo", Map.of(), null, true, Map.of("id", RedactRule.MASK)))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> own.validateNavigation("demo", Map.of(), null, false, Map.of()))
                .isInstanceOf(IllegalArgumentException.class);
        var paging = new OutputViewSpec("列表", fields, new OutputViewSpec.Pagination("page", "pageSize"), null);
        assertThatThrownBy(() -> paging.validateNavigation("demo", Map.of(), null, true, Map.of()))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void navigationIsIncludedInReviewedDigest() throws Exception {
        byte[] raw;
        try (var in = getClass().getResourceAsStream("/agent-registration-output-v3.json")) {
            raw = in.readAllBytes();
        }
        var manifest = new AgentManifestCodec().decode(raw);
        var old = manifest.outputView();
        var navigation = new OutputViewSpec(
                old.title(),
                old.fields(),
                null,
                new OutputViewSpec.Detail("详情", "crm.record.detail", "recordId", "id"));
        manifest = new CapabilityManifest(
                manifest.projectCode(),
                manifest.code(),
                manifest.version(),
                manifest.description(),
                manifest.permission(),
                manifest.dataScope(),
                manifest.params(),
                manifest.outboundFields(),
                manifest.redact(),
                manifest.readOnly(),
                manifest.idempotent(),
                manifest.confirmation(),
                manifest.timeoutMs(),
                manifest.inputForm(),
                navigation);
        assertThat(AgentManifestCodec.digest(new AgentManifestCodec().canonical(manifest)))
                .isNotEqualTo("2a788d17ed0ddb1ed57fe75b054e93cc069af626119e6e84c2319aa03d14bcb5");
    }
}
