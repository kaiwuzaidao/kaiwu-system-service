package com.kaiwu.module.agent.protocol;

import com.kaiwu.common.ApiException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.TreeMap;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import tools.jackson.core.StreamReadConstraints;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.core.json.JsonFactory;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.MapperFeature;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

/** 限定体积、深度与字段；规范化摘要不受 JSON 字段、参数或集合顺序影响。 */
@Component
public class AgentManifestCodec {
    public static final int MAX_BYTES = 65_536;
    private final ObjectMapper json = JsonMapper.builder(JsonFactory.builder()
                    .streamReadConstraints(StreamReadConstraints.builder()
                            .maxNestingDepth(12)
                            .maxStringLength(8000)
                            .maxNumberLength(20)
                            .build())
                    .build())
            .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
            .enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION)
            .disable(MapperFeature.ALLOW_COERCION_OF_SCALARS)
            .build();

    public CapabilityManifest decode(byte[] body) {
        if (body == null || body.length == 0 || body.length > MAX_BYTES) throw invalid();
        try {
            return json.readValue(body, CapabilityManifest.class);
        } catch (RuntimeException exception) {
            throw invalid();
        }
    }

    public String canonical(CapabilityManifest manifest) {
        return json.writeValueAsString(sorted(json.valueToTree(manifest), ""));
    }

    private Object sorted(JsonNode node, String field) {
        if (node.isObject()) {
            var map = new TreeMap<String, Object>();
            node.properties().forEach(entry -> map.put(entry.getKey(), sorted(entry.getValue(), entry.getKey())));
            return map;
        }
        // V1 arrays remain unordered sets (outboundFields / enum values).
        if (node.isArray()) {
            var values = node.values().stream().map(value -> sorted(value, ""));
            // UI fields are a sequence: reordering requires a new reviewed digest.
            return "fields".equals(field)
                    ? values.toList()
                    : values.sorted(java.util.Comparator.comparing(json::writeValueAsString))
                            .toList();
        }
        return node;
    }

    public static String digest(String text) {
        try {
            return HexFormat.of()
                    .formatHex(MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 unavailable", exception);
        }
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "能力清单格式或大小不合法", "api.validation.failed");
    }
}
