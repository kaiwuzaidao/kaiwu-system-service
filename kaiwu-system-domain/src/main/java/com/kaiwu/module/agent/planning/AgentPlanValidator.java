package com.kaiwu.module.agent.planning;

import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.ParamSpec;
import com.kaiwu.starter.KaiwuContext;
import java.time.format.DateTimeParseException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Component;

/**
 * 计划校验器：把模型输出当**不可信参数**校验，而不是当指令执行。
 *
 * <p>九条规则任一失败即整体拒绝，不做部分执行——放过一半的计划，用户拿到的是
 * 一个看起来成功、实则残缺的答复，比直接失败更难发现。</p>
 *
 * <p>钳制与拒绝的分界：数值越界钳制（模型把 20 写成 200 是常见抖动，为此让用户
 * 重问一遍不合理），枚举与类型错误拒绝（那说明模型没理解意图）。</p>
 */
@Component
public class AgentPlanValidator {

    /** 单次计划允许的最大能力数，防止一个问题引发一串查询。 */
    static final int MAX_CALLS = 3;

    private final CapabilityCatalog catalog;

    public AgentPlanValidator(CapabilityCatalog catalog) {
        this.catalog = catalog;
    }

    /**
     * 校验并归一化计划。
     *
     * @param visibleProjectIds 调用者有成员关系的项目，用于规则 9
     * @return 参数已钳制、已填默认值的计划
     */
    public AgentPlan validate(AgentPlan plan, KaiwuContext actor, Set<String> visibleProjectIds) {
        if (plan == null) {
            throw new PlanRejectedException(1, "模型未返回可解析的计划");
        }
        // Only explicitly declared forms may collect missing values. Validate supplied
        // fields and authorization even when the model marks the plan incomplete.
        if (plan.calls().size() == 1) {
            AgentPlan.Call call = plan.calls().getFirst();
            var capability =
                    catalog.findVisible(call.code(), actor).orElseThrow(() -> new PlanRejectedException(3, "无权限操作"));
            if (capability.inputForm() != null) {
                var supplied = new LinkedHashMap<>(call.params());
                supplied.entrySet()
                        .removeIf(entry -> capability.hasParam(entry.getKey())
                                && (entry.getValue() == null
                                        || entry.getValue() instanceof String text && text.isBlank()));
                boolean incomplete = !plan.understood()
                        || capability.paramsSchema().entrySet().stream()
                                .anyMatch(
                                        entry -> entry.getValue().required() && !supplied.containsKey(entry.getKey()));
                if (incomplete)
                    return new AgentPlan(
                            false,
                            List.of(validateCall(
                                    new AgentPlan.Call(call.code(), supplied), actor, visibleProjectIds, true)),
                            plan.clarification());
            }
        }
        if (!plan.understood()) {
            return plan;
        }
        // 规则 2：条数上限。
        if (plan.calls().size() > MAX_CALLS) {
            throw new PlanRejectedException(2, "单次最多执行 " + MAX_CALLS + " 个能力");
        }
        List<AgentPlan.Call> normalized = plan.calls().stream()
                .map(call -> validateCall(call, actor, visibleProjectIds))
                .toList();
        if (normalized.size() > 1
                && normalized.stream().anyMatch(call -> !catalog.findVisible(call.code(), actor)
                        .orElseThrow(() -> new PlanRejectedException(3, "无权限操作"))
                        .canSkipConfirmation())) throw new PlanRejectedException(4, "写操作必须单独预览确认，不能与其他操作混合");
        return new AgentPlan(true, normalized, plan.clarification());
    }

    /** Explicit form values must not be silently coerced, truncated or clamped like model guesses. */
    public AgentPlan validateInput(AgentPlan plan, KaiwuContext actor, Set<String> visibleProjectIds) {
        for (var call : plan.calls()) {
            var capability =
                    catalog.findVisible(call.code(), actor).orElseThrow(() -> new PlanRejectedException(3, "无权限操作"));
            for (var entry : call.params().entrySet()) {
                var spec = capability.paramsSchema().get(entry.getKey());
                if (spec == null) throw new PlanRejectedException(5, "表单包含未知参数");
                Object value = entry.getValue();
                if (value == null) continue;
                boolean valid =
                        switch (spec.type()) {
                            case STRING ->
                                value instanceof String text
                                        && (spec.maxLength() == null || text.length() <= spec.maxLength());
                            case STRING_LIST -> validStringList(spec, value);
                            case BOOL -> value instanceof Boolean;
                            case INT -> exactInteger(value, spec);
                            case ENUM ->
                                value instanceof String text
                                        && spec.values() != null
                                        && spec.values().contains(text);
                            case DATETIME -> exactDateTime(value);
                        };
                if (!valid) throw new PlanRejectedException(6, "表单参数类型或范围不合法");
            }
        }
        return validate(plan, actor, visibleProjectIds);
    }

    private static boolean exactDateTime(Object value) {
        if (!(value instanceof String text) || text.length() > 40) return false;
        try {
            java.time.LocalDateTime.parse(text);
            return true;
        } catch (DateTimeParseException invalid) {
            return false;
        }
    }

    private static boolean exactInteger(Object value, ParamSpec spec) {
        if (!(value instanceof Number number)) return false;
        try {
            int integer = new java.math.BigDecimal(number.toString()).intValueExact();
            return (spec.min() == null || integer >= spec.min()) && (spec.max() == null || integer <= spec.max());
        } catch (ArithmeticException | NumberFormatException invalid) {
            return false;
        }
    }

    private AgentPlan.Call validateCall(AgentPlan.Call call, KaiwuContext actor, Set<String> visibleProjectIds) {
        return validateCall(call, actor, visibleProjectIds, false);
    }

    private AgentPlan.Call validateCall(
            AgentPlan.Call call, KaiwuContext actor, Set<String> visibleProjectIds, boolean partial) {
        // 规则 3：能力必须在裁剪后的目录内。越权与不存在给同一种结果，不泄露能力是否存在。
        Capability capability =
                catalog.findVisible(call.code(), actor).orElseThrow(() -> new PlanRejectedException(3, "无权限操作"));

        // 规则 4：直接执行仅限平台已认定只读的能力，不能信任远程自报的 readOnly。
        boolean approvedLocalWrite =
                Capability.SYSTEM_PROJECT_CODE.equals(capability.projectCode()) && !capability.readOnly();
        boolean approvedRemoteWrite = !Capability.SYSTEM_PROJECT_CODE.equals(capability.projectCode())
                && !capability.readOnly()
                && capability.idempotent()
                && catalog.isApprovedWrite(capability, actor);
        if (!capability.canSkipConfirmation() && !approvedLocalWrite && !approvedRemoteWrite) {
            throw new PlanRejectedException(4, "该能力尚未获准直接执行：" + capability.code());
        }

        Map<String, Object> result = new LinkedHashMap<>();
        for (Map.Entry<String, Object> entry : call.params().entrySet()) {
            String name = entry.getKey();
            // 规则 5：拒绝 schema 之外的字段。身份类字段在能力注册时已被禁止声明，
            // 因此它们必然落进这一条。
            if (!capability.hasParam(name)) {
                throw new PlanRejectedException(5, capability.code() + " 不接受参数：" + name);
            }
            ParamSpec spec = capability.paramsSchema().get(name);
            result.put(name, coerce(capability, name, spec, entry.getValue(), visibleProjectIds));
        }

        // 规则 6：必填齐全；并补上未提供的默认值。
        capability.paramsSchema().forEach((name, spec) -> {
            if (!result.containsKey(name)) {
                if (spec.required() && !partial) {
                    throw new PlanRejectedException(6, capability.code() + " 缺少必填参数：" + name);
                }
                if (spec.defaultValue() != null) {
                    result.put(name, spec.defaultValue());
                }
            }
        });
        return new AgentPlan.Call(capability.code(), result);
    }

    private Object coerce(
            Capability capability, String name, ParamSpec spec, Object raw, Set<String> visibleProjectIds) {
        if (raw == null) {
            if (spec.required() && !Capability.SYSTEM_PROJECT_CODE.equals(capability.projectCode()))
                throw new PlanRejectedException(6, "必填参数不能为空");
            return null;
        }
        return switch (spec.type()) {
            case INT -> clampInt(capability, name, spec, raw);
            case BOOL -> asBool(capability, name, raw);
            case DATETIME -> asDateTime(capability, name, raw);
            case ENUM -> inEnum(capability, name, spec, raw);
            case STRING -> asString(capability, name, spec, raw, visibleProjectIds);
            case STRING_LIST -> {
                if (!validStringList(spec, raw))
                    throw new PlanRejectedException(6, capability.code() + "." + name + " 列表参数不合法");
                yield java.util.List.copyOf((java.util.List<?>) raw);
            }
        };
    }

    public static boolean validStringList(ParamSpec spec, Object raw) {
        if (!(raw instanceof java.util.List<?> list)
                || spec.min() == null
                || spec.max() == null
                || spec.maxLength() == null
                || list.size() < spec.min()
                || list.size() > spec.max()) return false;
        return list.stream()
                        .allMatch(item -> item instanceof String text
                                && !text.isBlank()
                                && text.equals(text.trim())
                                && text.length() <= spec.maxLength())
                && new java.util.HashSet<>(list).size() == list.size();
    }

    /** 规则 6b：数值越界钳制到边界，不拒绝。 */
    private int clampInt(Capability capability, String name, ParamSpec spec, Object raw) {
        int value;
        if (raw instanceof Number number) {
            if (!Capability.SYSTEM_PROJECT_CODE.equals(capability.projectCode())) {
                try {
                    value = new java.math.BigDecimal(number.toString()).intValueExact();
                } catch (ArithmeticException | NumberFormatException invalid) {
                    throw new PlanRejectedException(6, "远程能力参数不是有效整数");
                }
            } else value = number.intValue();
        } else {
            if (!capability.readOnly()) throw new PlanRejectedException(6, "写操作整数参数类型错误");
            try {
                value = Integer.parseInt(String.valueOf(raw).trim());
            } catch (NumberFormatException exception) {
                throw new PlanRejectedException(6, capability.code() + "." + name + " 不是整数");
            }
        }
        if (spec.min() != null && value < spec.min()) {
            if (!capability.readOnly()) throw new PlanRejectedException(6, "写操作整数参数越界");
            value = spec.min();
        }
        if (spec.max() != null && value > spec.max()) {
            if (!capability.readOnly()) throw new PlanRejectedException(6, "写操作整数参数越界");
            value = spec.max();
        }
        return value;
    }

    private boolean asBool(Capability capability, String name, Object raw) {
        if (raw instanceof Boolean bool) {
            return bool;
        }
        if (!capability.readOnly()) throw new PlanRejectedException(6, "写操作布尔参数类型错误");
        String text = String.valueOf(raw).trim();
        if ("true".equalsIgnoreCase(text) || "false".equalsIgnoreCase(text)) {
            return Boolean.parseBoolean(text);
        }
        throw new PlanRejectedException(6, capability.code() + "." + name + " 不是布尔值");
    }

    private String asDateTime(Capability capability, String name, Object raw) {
        if (!capability.readOnly() && !(raw instanceof String)) throw new PlanRejectedException(6, "写操作时间参数类型错误");
        String text = String.valueOf(raw).trim();
        try {
            java.time.LocalDateTime.parse(text);
            return text;
        } catch (DateTimeParseException exception) {
            throw new PlanRejectedException(6, capability.code() + "." + name + " 不是合法时间");
        }
    }

    private String inEnum(Capability capability, String name, ParamSpec spec, Object raw) {
        if (!capability.readOnly() && !(raw instanceof String)) throw new PlanRejectedException(6, "写操作枚举参数类型错误");
        String text = String.valueOf(raw).trim();
        if (spec.values() != null && !spec.values().contains(text)) {
            throw new PlanRejectedException(6, capability.code() + "." + name + " 取值非法：" + text);
        }
        return text;
    }

    private String asString(
            Capability capability, String name, ParamSpec spec, Object raw, Set<String> visibleProjectIds) {
        if (!capability.readOnly()
                && (!(raw instanceof String)
                        || (spec.maxLength() != null && ((String) raw).length() > spec.maxLength())))
            throw new PlanRejectedException(6, "写操作参数必须为长度合法的字符串");
        String text = String.valueOf(raw).trim();
        // 规则 9：projectId 必须在可见项目清单内。只裁剪能力挡不住模型凭问题里的
        // 名字编造无权项目；拒绝话术不区分「不存在」与「无权限」，错误信息本身也是信息。
        if (ParamSpec.VISIBLE_PROJECTS.equals(spec.enumFrom()) && !visibleProjectIds.contains(text)) {
            throw new PlanRejectedException(9, "没有找到你有权限的项目");
        }
        // 规则 7：超长截断而非拒绝，截断事实由调用方记入元数据。
        if (spec.maxLength() != null && text.length() > spec.maxLength()) {
            return text.substring(0, spec.maxLength());
        }
        return text;
    }
}
