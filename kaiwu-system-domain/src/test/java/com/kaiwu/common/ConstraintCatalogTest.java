package com.kaiwu.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/** 校验 ADR 0020 的机器可读约束目录与有期限 waiver。 */
class ConstraintCatalogTest {

    private static final Path CATALOG = Path.of("../docs/kaiwu-constraints.json");
    private static final Path WAIVERS = Path.of("../docs/kaiwu-constraint-waivers.json");
    private static final Set<String> LEVELS = Set.of("MUST", "WARN", "DEFAULT");

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void catalogAndWaiversAreValid() throws Exception {
        JsonNode constraints = objectMapper.readTree(Files.readString(CATALOG)).path("constraints");
        assertThat(constraints.isArray()).isTrue();

        Map<String, Boolean> waivable = new HashMap<>();
        Set<String> ids = new HashSet<>();
        for (JsonNode constraint : constraints) {
            String id = requiredText(constraint, "id");
            assertThat(ids.add(id)).as("约束 ID 必须唯一：%s", id).isTrue();
            assertThat(LEVELS).contains(requiredText(constraint, "level"));
            requiredText(constraint, "scope");
            requiredText(constraint, "rationale");
            requiredText(constraint, "enforcement");
            LocalDate.parse(requiredText(constraint, "reviewAfter"));
            assertThat(constraint.has("waivable")).as("%s 缺 waivable", id).isTrue();
            boolean canWaive = constraint.path("waivable").asBoolean(false);
            if ("MUST".equals(constraint.path("level").asText())) {
                assertThat(canWaive).as("MUST 约束不得允许 waiver：%s", id).isFalse();
            }
            waivable.put(id, canWaive);
        }

        JsonNode waivers = objectMapper.readTree(Files.readString(WAIVERS)).path("waivers");
        assertThat(waivers.isArray()).isTrue();
        for (JsonNode waiver : waivers) {
            String id = requiredText(waiver, "constraintId");
            assertThat(waivable).as("waiver 引用了不存在的约束：%s", id).containsKey(id);
            assertThat(waivable.get(id)).as("该约束不允许 waiver：%s", id).isTrue();
            requiredText(waiver, "owner");
            requiredText(waiver, "reason");
            LocalDate expiresAt = LocalDate.parse(requiredText(waiver, "expiresAt"));
            assertThat(expiresAt).as("waiver 已过期：%s", id).isAfterOrEqualTo(LocalDate.now(ZoneOffset.UTC));
        }
    }

    /**
     * 复核到期只报告、不阻断。
     *
     * <p>{@code reviewAfter} 原本没有任何行为，那这些日期就只是装饰——一条规则如果永远不会被
     * 重新审视，它到底还成不成立就没人知道了。这里把过期项打进构建输出，让它在 CI 日志里
     * 可见；不阻断是因为「日历到期」本身不代表产物有问题，用红灯逼人改日期只会让人把日期
     * 往后推十年。</p>
     */
    @Test
    void reportsConstraintsPastTheirReviewDate() throws Exception {
        JsonNode constraints = objectMapper.readTree(Files.readString(CATALOG)).path("constraints");
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        List<String> expired = new ArrayList<>();
        for (JsonNode constraint : constraints) {
            LocalDate reviewAfter =
                    LocalDate.parse(constraint.path("reviewAfter").asText());
            if (reviewAfter.isBefore(today)) {
                expired.add(constraint.path("id").asText() + "（" + reviewAfter + "）");
            }
        }

        if (expired.isEmpty()) {
            System.out.println("[constraints] 所有约束都在复核有效期内。");
            return;
        }
        System.out.println("[constraints] WARN 以下约束已过复核日期，请确认仍然成立后再顺延：" + String.join("、", expired));
    }

    private static String requiredText(JsonNode node, String field) {
        String value = node.path(field).asText("").trim();
        assertThat(value).as("缺少非空字段 %s", field).isNotEmpty();
        return value;
    }
}
