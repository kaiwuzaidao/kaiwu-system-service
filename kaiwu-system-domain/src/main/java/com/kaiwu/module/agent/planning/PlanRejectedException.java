package com.kaiwu.module.agent.planning;

/**
 * 计划校验失败。
 *
 * <p>携带规则编号便于观测：规则 3（能力越界）与规则 9（项目越界）的计数是判断
 * 提示词是否被绕过的信号，需要单独统计而不是混在通用失败里。</p>
 */
public class PlanRejectedException extends RuntimeException {

    private final int rule;

    public PlanRejectedException(int rule, String message) {
        super(message);
        this.rule = rule;
    }

    public int rule() {
        return rule;
    }
}
