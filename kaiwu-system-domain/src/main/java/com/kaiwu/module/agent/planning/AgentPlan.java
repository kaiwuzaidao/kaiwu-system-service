package com.kaiwu.module.agent.planning;

import java.util.List;
import java.util.Map;

/**
 * 模型产出的调用计划，经 {@link AgentPlanValidator} 校验后才可执行。
 *
 * <p>它是模型输出的解析结果，属于**不可信输入**：校验前的任何字段都不得直接使用。</p>
 *
 * @param understood 模型是否理解了问题；为 false 时只使用 clarification
 * @param clarification 需要向用户追问的话
 */
public record AgentPlan(boolean understood, List<Call> calls, String clarification) {

    public AgentPlan {
        calls = calls == null ? List.of() : List.copyOf(calls);
    }

    /** 计划中的一次能力调用。 */
    public record Call(String code, Map<String, Object> params) {

        public Call {
            params = params == null ? Map.of() : Map.copyOf(params);
        }
    }
}
