package com.kaiwu.module.agent.audit;

import java.util.EnumMap;
import java.util.Map;

/**
 * 一次 Agent 提问的分阶段计时与规模记录，只服务于评估日志（方案 V1.6 §5.1，P0 基线）。
 *
 * <p>用 {@link System#nanoTime()} 计时，不受系统时钟回拨影响；没有执行到的阶段保持空值，
 * 不记 0，避免把「没走到」误读成「很快」。实例只在一次 {@code ask()} 调用内、由请求线程使用，
 * 不跨线程共享，因此不做同步。P1b 引入并行执行时，各能力的耗时应由各自线程写入独立记录后再汇总，
 * 不能直接共用本实例。</p>
 *
 * <p>只保存时长、个数与字符数，不保存提问、参数值、提示词和返回内容，
 * 与 {@link EvaluationRecorder} 的脱敏边界一致。</p>
 */
public final class AgentEvalTrace {

    /** 请求内的计时阶段；预处理、规划、校验、执行、总结互不重叠。 */
    public enum Stage {
        /** 限流、能力目录裁剪、意图守卫、取模型配置、构造规划提示词。 */
        PREPROCESS,
        /** 规划模型调用及解析计划。 */
        PLAN_MODEL,
        /** 计划校验。 */
        PLAN_VALIDATE,
        /** 全部能力的复核与调用。 */
        EXECUTE,
        /** 总结模型调用。 */
        ANSWER_MODEL
    }

    private final String correlationId;
    private final long startedNanos = System.nanoTime();
    private final Map<Stage, Long> elapsedMillis = new EnumMap<>(Stage.class);
    private final Map<Stage, Long> openedNanos = new EnumMap<>(Stage.class);

    private Integer visibleCapabilityCount;
    private Integer planningPromptChars;
    private Integer historyTurns;
    private Integer memoryCount;
    private Integer questionChars;
    private Integer plannedCallCount;
    private int modelCallCount;
    private Long planPromptTokenCount;
    private Long planCompletionTokenCount;
    private Long answerPromptTokenCount;
    private Long answerCompletionTokenCount;

    public AgentEvalTrace(String correlationId) {
        this.correlationId = correlationId;
    }

    public String correlationId() {
        return correlationId;
    }

    /** 开始一个阶段；同一阶段再次开始会重新计时，不累加。 */
    public void begin(Stage stage) {
        openedNanos.put(stage, System.nanoTime());
    }

    /** 结束阶段并记录耗时；没有对应的 {@link #begin} 时忽略，已结束的阶段不重复记录。 */
    public void end(Stage stage) {
        Long opened = openedNanos.remove(stage);
        if (opened != null) elapsedMillis.put(stage, (System.nanoTime() - opened) / 1_000_000);
    }

    /** 结束所有仍在计时的阶段；提前返回的分支在写评估事件前调用，使被打断的阶段也有耗时。 */
    public void endOpen() {
        for (Stage stage : java.util.List.copyOf(openedNanos.keySet())) end(stage);
    }

    /** 阶段耗时（毫秒）；该阶段没有执行时为 {@code null}。 */
    public Long elapsed(Stage stage) {
        return elapsedMillis.get(stage);
    }

    /** 从请求开始到现在的总耗时（毫秒）。 */
    public long totalMillis() {
        return (System.nanoTime() - startedNanos) / 1_000_000;
    }

    /** 总耗时中没有归入任何阶段的部分，例如总结提示词构造、卡片组装、审计写入。 */
    public long unattributedMillis() {
        long attributed =
                elapsedMillis.values().stream().mapToLong(Long::longValue).sum();
        return Math.max(0, totalMillis() - attributed);
    }

    /** 记录规划前的规模：可见能力数、规划提示词字符数、历史轮数、记忆条数、提问字符数。 */
    public void scale(int visibleCapabilities, int promptChars, int historyTurns, int memoryCount, int questionChars) {
        this.visibleCapabilityCount = visibleCapabilities;
        this.planningPromptChars = promptChars;
        this.historyTurns = historyTurns;
        this.memoryCount = memoryCount;
        this.questionChars = questionChars;
    }

    public void plannedCalls(int count) {
        this.plannedCallCount = count;
    }

    /** 记录一次已发出的模型调用及其 token 用量；用量缺失时保持空值。 */
    public void modelCalled(ModelStage stage, Long promptTokenCount, Long completionTokenCount) {
        modelCallCount++;
        if (stage == ModelStage.PLAN) {
            planPromptTokenCount = promptTokenCount;
            planCompletionTokenCount = completionTokenCount;
        } else {
            answerPromptTokenCount = promptTokenCount;
            answerCompletionTokenCount = completionTokenCount;
        }
    }

    /** 记录一次失败的模型调用，只计次数。 */
    public void modelCallFailed() {
        modelCallCount++;
    }

    public Integer visibleCapabilityCount() {
        return visibleCapabilityCount;
    }

    public Integer planningPromptChars() {
        return planningPromptChars;
    }

    public Integer historyTurns() {
        return historyTurns;
    }

    public Integer memoryCount() {
        return memoryCount;
    }

    public Integer questionChars() {
        return questionChars;
    }

    public Integer plannedCallCount() {
        return plannedCallCount;
    }

    public int modelCallCount() {
        return modelCallCount;
    }

    public Long planPromptTokenCount() {
        return planPromptTokenCount;
    }

    public Long planCompletionTokenCount() {
        return planCompletionTokenCount;
    }

    public Long answerPromptTokenCount() {
        return answerPromptTokenCount;
    }

    public Long answerCompletionTokenCount() {
        return answerCompletionTokenCount;
    }

    /** 模型调用所属的编排阶段，对应评估日志里的 {@code stage}。 */
    public enum ModelStage {
        PLAN,
        ANSWER
    }
}
