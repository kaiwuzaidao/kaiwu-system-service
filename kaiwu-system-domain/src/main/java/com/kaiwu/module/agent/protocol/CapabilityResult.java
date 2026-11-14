package com.kaiwu.module.agent.protocol;

import java.util.List;
import java.util.Map;

/**
 * 一次能力调用的原始结果，尚未投影。
 *
 * <p>它同时喂给两种投影，因此**不得**直接送往模型或前端——那正是双投影要防的事。
 *
 * @param sourceProjects 结果涉及的项目，供卡片保留来源标记
 * @param failure 非空表示该条能力执行失败；其余能力的结果照常返回
 */
public record CapabilityResult(
        String capabilityCode,
        String title,
        List<Map<String, Object>> rows,
        List<String> sourceProjects,
        String failure) {

    public CapabilityResult {
        rows = rows == null ? List.of() : List.copyOf(rows);
        sourceProjects = sourceProjects == null ? List.of() : List.copyOf(sourceProjects);
    }

    public static CapabilityResult ok(
            String code, String title, List<Map<String, Object>> rows, List<String> sourceProjects) {
        return new CapabilityResult(code, title, rows, sourceProjects, null);
    }

    public static CapabilityResult failed(String code, String title, String failure) {
        return new CapabilityResult(code, title, List.of(), List.of(), failure);
    }

    public boolean succeeded() {
        return failure == null;
    }
}
