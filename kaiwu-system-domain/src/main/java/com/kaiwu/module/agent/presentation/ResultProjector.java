package com.kaiwu.module.agent.presentation;

import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.RedactRule;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * 把能力执行结果分别投影成卡片与模型两种形态。
 *
 * <p>顺序固定为：<b>权限过滤 → 字段白名单 → 脱敏 → 大小截断 → 序列化</b>。
 * 颠倒会让截断发生在脱敏之前，产生「截了一半的手机号」这类残留
 * （ADR 0030 第 10 条）。权限过滤发生在调用方，进入本类的行已经是调用者有权看的。</p>
 *
 * <p>本类是 {@link ModelProjection} 的唯一构造入口。</p>
 */
@Component
public class ResultProjector {

    /** 单次送模型的最大行数。超出摘要或截断，并告知用户。 */
    static final int MAX_MODEL_ROWS = 50;

    /** 单次送模型的最大字符数，与行数先到者生效。 */
    static final int MAX_MODEL_CHARS = 32 * 1024;

    private static final Logger log = LoggerFactory.getLogger(ResultProjector.class);

    /** 卡片投影：保留原值与来源标记，供浏览器渲染与历史重授权。 */
    public CardProjection toCard(
            Capability capability, String title, List<Map<String, Object>> rows, List<String> sourceProjects) {
        if (!Capability.SYSTEM_PROJECT_CODE.equals(capability.projectCode())) {
            // 远程结果对浏览器同样执行审核字段和脱敏规则，不能信任 Handler 已经投影。
            List<Map<String, Object>> safe = new ArrayList<>();
            for (var row : toModel(capability, rows).rows()) {
                var copy = new LinkedHashMap<>(row);
                if (sourceProjects.size() == 1) copy.put(CardProjection.SOURCE_PROJECT_ID, sourceProjects.getFirst());
                safe.add(copy);
            }
            rows = safe;
        }
        CardProjection.CardType type = rows.isEmpty() ? CardProjection.CardType.EMPTY : CardProjection.CardType.TABLE;
        return new CardProjection(type, title, rows, sourceProjects, Instant.now());
    }

    /**
     * 模型投影：按 {@code outboundFields} 逐字段复制。
     *
     * <p>默认全部不外发——未列入白名单的字段不会被复制，因此新增字段不会因为
     * 「忘了排除」而泄露。未知字段、缺失字段与脱敏异常一律丢弃并记结构化失败，
     * 不静默通过。</p>
     */
    public ModelProjection toModel(Capability capability, List<Map<String, Object>> rows) {
        List<Map<String, Object>> projected = new ArrayList<>();
        int chars = 0;
        boolean truncated = false;

        for (Map<String, Object> row : rows) {
            if (projected.size() >= MAX_MODEL_ROWS) {
                truncated = true;
                break;
            }
            Map<String, Object> copy = new LinkedHashMap<>();
            for (String field : capability.outboundFields()) {
                if (!row.containsKey(field)) {
                    log.debug("capability={} outbound field absent in result: field={}", capability.code(), field);
                    continue;
                }
                Object value = row.get(field);
                RedactRule rule = capability.redact().get(field);
                if (rule != null) {
                    value = redact(capability, field, value, rule);
                    if (value == null) {
                        continue;
                    }
                }
                copy.put(field, value);
            }
            chars += estimateChars(copy);
            if (chars > MAX_MODEL_CHARS) {
                truncated = true;
                break;
            }
            projected.add(copy);
        }
        return ModelProjection.copyWhitelisted(capability.code(), projected, truncated);
    }

    private Object redact(Capability capability, String field, Object value, RedactRule rule) {
        if (value == null) {
            return null;
        }
        String text = String.valueOf(value);
        try {
            return switch (rule) {
                case MASK -> "***";
                case PARTIAL -> text.isEmpty() ? "" : text.charAt(0) + "*".repeat(Math.max(1, text.length() - 1));
            };
        } catch (RuntimeException exception) {
            // 脱敏出错时丢弃该字段而不是原样外发，并留下可观测的失败记录。
            log.warn(
                    "capability={} redaction failed, field dropped: field={} rule={}",
                    capability.code(),
                    field,
                    rule.name().toLowerCase(Locale.ROOT));
            return null;
        }
    }

    private int estimateChars(Map<String, Object> row) {
        int total = 0;
        for (Map.Entry<String, Object> entry : row.entrySet()) {
            total += entry.getKey().length();
            total += entry.getValue() == null
                    ? 4
                    : String.valueOf(entry.getValue()).length();
        }
        return total;
    }
}
