package com.kaiwu.module.agent.planning;

import com.kaiwu.common.ApiException;
import com.kaiwu.port.AgentAiPort;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * 调模型产出调用计划，并把返回文本解析成 {@link AgentPlan}。
 *
 * <p>解析结果是**不可信输入**，本类只负责取出结构，判定合法与否由
 * {@link AgentPlanValidator} 完成——解析和校验分开，才不会出现「解析时顺手放行」。</p>
 *
 * <p>Provider 不可用、超时或返回非法结构时整体失败并明确提示，
 * 不做降级猜测、不退化为关键词匹配（ADR 0030 第 13 条，与 ADR 0006 对
 * AI_PROJECT 失败的处理一致）。</p>
 */
@Component
public class AgentPlanner {

    /** 规划只返回 JSON 计划，给得比总结少。 */
    static final int PLANNING_MAX_TOKENS = 1000;

    /** 总结要生成自然语言答复。 */
    static final int ANSWER_MAX_TOKENS = 2000;

    private static final Logger log = LoggerFactory.getLogger(AgentPlanner.class);

    private final AgentAiPort ai;
    private final ObjectMapper objectMapper;

    public AgentPlanner(AgentAiPort ai, ObjectMapper objectMapper) {
        this.ai = ai;
        this.objectMapper = objectMapper;
    }

    /** 固定本次请求的模型目标，不在快照中保存凭据。 */
    public Target requireProvider(String purpose) {
        AgentAiPort.RoutedConfig route = ai.effectiveFor(purpose)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.SERVICE_UNAVAILABLE, "AI 助手需要先配置大模型 Provider", "api.common.serviceUnavailable"));
        AgentAiPort.RuntimeConfig config = route.config();
        return new Target(
                purpose,
                route.modelId(),
                config.providerName(),
                config.baseUrl(),
                config.model(),
                config.temperature(),
                config.timeoutSeconds(),
                hasKey(config.apiKey()));
    }

    /** 发起调用前重新读取当前凭据并验证目标；改变目标或撤销凭据时失败，不静默换模型。 */
    private AgentAiPort.RuntimeConfig resolve(Target target) {
        AgentAiPort.RoutedConfig route =
                ai.effectiveFor(target.purpose()).orElseThrow(() -> new IllegalStateException("模型配置已不可用"));
        AgentAiPort.RuntimeConfig current = route.config();
        if (!java.util.Objects.equals(target.modelId(), route.modelId())
                || !java.util.Objects.equals(target.providerName(), current.providerName())
                || !java.util.Objects.equals(target.baseUrl(), current.baseUrl())
                || !java.util.Objects.equals(target.model(), current.model())
                || (target.hadKey() && !hasKey(current.apiKey()))) {
            throw new IllegalStateException("模型目标或凭据已变化，请重新发起请求");
        }
        return new AgentAiPort.RuntimeConfig(
                target.providerName(),
                target.baseUrl(),
                current.apiKey(),
                target.model(),
                target.temperature(),
                target.timeoutSeconds());
    }

    private static boolean hasKey(String key) {
        return key != null && !key.isBlank();
    }

    /** 本次请求固定的非敏感目标；密钥仅在模型调用前读取。 */
    public record Target(
            String purpose,
            String modelId,
            String providerName,
            String baseUrl,
            String model,
            java.math.BigDecimal temperature,
            int timeoutSeconds,
            boolean hadKey) {}

    /** 第一次调用：产出计划。 */
    public Planned plan(Target target, String systemPrompt, String question) {
        AgentAiPort.ChatOutcome outcome = ai.chat(resolve(target), systemPrompt, question, PLANNING_MAX_TOKENS);
        return new Planned(parse(outcome.content()), outcome.promptTokens(), outcome.completionTokens());
    }

    /** 第二次调用：把结果转成自然语言。 */
    public Answered answer(Target target, String systemPrompt, String userPrompt) {
        AgentAiPort.ChatOutcome outcome = ai.chat(resolve(target), systemPrompt, userPrompt, ANSWER_MAX_TOKENS);
        String content = outcome.content() == null ? "" : outcome.content().trim();
        return new Answered(content, outcome.promptTokens(), outcome.completionTokens());
    }

    /**
     * 解析模型返回的 JSON。
     *
     * <p>容忍被代码块包裹这一种常见偏差，其余一律按解析失败处理——
     * 越是「尽量兜住」，越容易把一个半懂的计划当成理解了。</p>
     */
    private AgentPlan parse(String raw) {
        String text = strip(raw);
        if (text.isEmpty()) {
            throw new PlanRejectedException(1, "模型没有返回内容");
        }
        try {
            JsonNode node = objectMapper.readTree(text);
            boolean understood = node.path("understood").asBoolean(false);
            String clarification = node.path("clarification").isNull()
                    ? null
                    : node.path("clarification").asString(null);
            List<AgentPlan.Call> calls = new ArrayList<>();
            JsonNode callsNode = node.path("calls");
            if (callsNode.isArray()) {
                for (JsonNode call : callsNode) {
                    String code = call.path("code").asString(null);
                    if (code == null || code.isBlank()) {
                        throw new PlanRejectedException(1, "计划中存在没有能力名的调用");
                    }
                    calls.add(new AgentPlan.Call(code, readParams(call.path("params"))));
                }
            }
            return new AgentPlan(understood, calls, clarification);
        } catch (PlanRejectedException rejected) {
            throw rejected;
        } catch (Exception exception) {
            // 只记异常类型与长度，不记模型返回的正文——它可能复述了用户问题。
            log.warn(
                    "agent plan parse failed: error={} length={}",
                    exception.getClass().getSimpleName(),
                    text.length());
            throw new PlanRejectedException(1, "模型返回的计划无法解析");
        }
    }

    private Map<String, Object> readParams(JsonNode params) {
        Map<String, Object> result = new LinkedHashMap<>();
        if (params == null || !params.isObject()) {
            return result;
        }
        for (Map.Entry<String, JsonNode> entry : params.properties()) {
            JsonNode value = entry.getValue();
            if (value.isNull()) {
                continue;
            }
            if (value.isNumber()) {
                result.put(entry.getKey(), value.numberValue());
            } else if (value.isBoolean()) {
                result.put(entry.getKey(), value.booleanValue());
            } else {
                result.put(entry.getKey(), value.asString());
            }
        }
        return result;
    }

    private String strip(String raw) {
        if (raw == null) {
            return "";
        }
        String text = raw.trim();
        if (text.startsWith("```")) {
            int firstLineBreak = text.indexOf('\n');
            int lastFence = text.lastIndexOf("```");
            if (firstLineBreak > 0 && lastFence > firstLineBreak) {
                text = text.substring(firstLineBreak + 1, lastFence).trim();
            }
        }
        return text;
    }

    /** @param plan 尚未校验的计划 */
    public record Planned(AgentPlan plan, Long promptTokens, Long completionTokens) {}

    public record Answered(String content, Long promptTokens, Long completionTokens) {}
}
