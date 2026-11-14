package com.kaiwu.module.agent.protocol;

import static org.assertj.core.api.Assertions.*;

import com.kaiwu.common.ApiException;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;

class AgentManifestCodecTest {
    private final AgentManifestCodec codec = new AgentManifestCodec();

    @Test
    void acceptsIndependentStarterProtocolFixture() throws Exception {
        try (var input = getClass().getResourceAsStream("/agent-registration-v1.json")) {
            assertThat(input).isNotNull();
            var manifest = codec.decode(input.readAllBytes());
            assertThat(new CapabilityManifestValidator()
                            .validate(manifest, "crm", java.util.Set.of("record:record:list")))
                    .isEqualTo(manifest);
            assertThat(AgentManifestCodec.digest(codec.canonical(manifest)))
                    .isEqualTo("85d4800dcf4e0f2656cd1e2f2d9f0ea8f684d48ecd50a7f4cef3a0d573eddf97");
            assertThat(manifest.params().get("pageSize").defaultValue()).isEqualTo(20);
        }
    }

    @Test
    void canonicalDigestIgnoresFieldAndSetOrder() {
        String a = codec.canonical(com.kaiwu.testing.AgentTestFixtures.manifest("1"));
        String b = a.replace("[\"id\",\"title\"]", "[\"title\",\"id\"]");
        assertThat(b).isNotEqualTo(a);
        assertThat(codec.canonical(codec.decode(b.getBytes(StandardCharsets.UTF_8))))
                .isEqualTo(a);
    }

    @Test
    void rejectsUnknownFieldsDuplicateKeysScalarCoercionAndOversizedBody() {
        String base = codec.canonical(com.kaiwu.testing.AgentTestFixtures.manifest("1"));
        for (String bad : new String[] {
            base + " {}",
            base.replaceFirst("\\{", "{\"verifiedReadOnly\":true,"),
            base.replaceFirst("\\{", "{\"readOnly\":false,"),
            base.replace("\"readOnly\":true", "\"readOnly\":\"true\""),
            "[".repeat(13) + "0" + "]".repeat(13)
        }) {
            assertThatThrownBy(() -> codec.decode(bad.getBytes(StandardCharsets.UTF_8)))
                    .isInstanceOf(ApiException.class);
        }
        assertThatThrownBy(() -> codec.decode(new byte[AgentManifestCodec.MAX_BYTES + 1]))
                .isInstanceOf(ApiException.class);
    }

    @Test
    void formOrderAndLabelsChangeApprovalDigestButV1NullExtensionDoesNot() throws Exception {
        try (var input = getClass().getResourceAsStream("/agent-registration-form-v2.json")) {
            var manifest = codec.decode(input.readAllBytes());
            String original = codec.canonical(manifest);
            var reversed = new java.util.ArrayList<>(manifest.inputForm().fields());
            java.util.Collections.reverse(reversed);
            var changed = new CapabilityManifest(
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
                    new InputFormSpec(manifest.inputForm().title(), reversed));
            assertThat(codec.canonical(changed)).isNotEqualTo(original);
            assertThat(AgentManifestCodec.digest(original.replace("关键词", "搜索词")))
                    .isNotEqualTo(AgentManifestCodec.digest(original));
        }
        String v1 = codec.canonical(com.kaiwu.testing.AgentTestFixtures.manifest("1"));
        String withNull = v1.replaceFirst("\\{", "{\"inputForm\":null,");
        assertThat(codec.canonical(codec.decode(withNull.getBytes(StandardCharsets.UTF_8))))
                .isEqualTo(v1);
    }
}
