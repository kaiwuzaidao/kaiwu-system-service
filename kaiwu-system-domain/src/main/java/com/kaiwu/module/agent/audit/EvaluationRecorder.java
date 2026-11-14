package com.kaiwu.module.agent.audit;

import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * 复核证据（ADR 0030 第 12 条）。
 *
 * <p>为什么非要单独一条链路：P1a 不落库会话，而 {@code logging.no-sensitive-data}
 * 禁止把提问原文与结果写进日志。两者叠加的结果是——三个月后想算准确率，
 * 一份可用数据都拿不到，用复核点换来的边界批准就落了空。</p>
 *
 * <p>因此只记脱敏后的结构化字段：能力 code、参数<b>键名</b>、校验结果、
 * 结果类型、涉及项目数、耗时与 token 数、模型与提示词版本。
 * <b>不记提问原文、参数值与结果内容。</b></p>
 *
 * <p>P1a 先写结构化日志，P1b 落独立表——表要有自己的访问控制与保留期，
 * 不与审计混放。现在就把字段定下来，避免上线后才发现缺列。</p>
 */
@Component
public class EvaluationRecorder {

    /**
     * 字段名用 {@code ...TokenCount} 而非 {@code ...Tokens}：它们是计数，不是凭据。
     * {@code SensitiveLoggingConventionTest} 按标识符结尾匹配 token 词根，
     * 叫 {@code promptTokens} 会被判成写出凭据——那条启发式挡的是
     * 「顺手把整个 token 打进日志」，这里改名比给门禁开口子更合适。
     */
    /** 提示词版本：提示词一改就要递增，否则历史准确率无法与版本对应。 */
    public static final String PROMPT_VERSION = "d2-1";

    private static final Logger log = LoggerFactory.getLogger(EvaluationRecorder.class);

    /** 只记原有字段；没有分阶段数据的调用点沿用，输出中的新增字段为空。 */
    public void record(Event event) {
        record(event, null);
    }

    /**
     * 记一条任务级评估事件。
     *
     * <p>原有字段名与含义不变，旧的日志查询仍然可用；分阶段耗时、规模与分阶段 token 以追加字段给出。
     * {@code trace} 为空时这些字段输出 {@code -}。阶段耗时没有执行到时也是 {@code -}，不是 0。</p>
     */
    public void record(Event event, AgentEvalTrace trace) {
        log.info(
                "agent_eval correlationId={} capabilities={} paramKeys={} validation={} outcome={} "
                        + "crossProjectCount={} latencyMs={} promptTokenCount={} completionTokenCount={} model={} promptVersion={} "
                        + "totalMs={} preprocessMs={} planModelMs={} planValidateMs={} executeMs={} answerModelMs={} unattributedMs={} "
                        + "visibleCapabilityCount={} planningPromptChars={} historyTurns={} memoryCount={} questionChars={} "
                        + "plannedCallCount={} modelCallCount={} "
                        + "planPromptTokenCount={} planCompletionTokenCount={} answerPromptTokenCount={} answerCompletionTokenCount={}",
                event.correlationId(),
                event.capabilityCodes(),
                event.paramKeys(),
                event.validationResult(),
                event.outcome(),
                event.crossProjectCount(),
                event.latencyMs(),
                event.promptTokenCount(),
                event.completionTokenCount(),
                event.model(),
                PROMPT_VERSION,
                trace == null ? NONE : trace.totalMillis(),
                trace == null ? NONE : orNone(trace.elapsed(AgentEvalTrace.Stage.PREPROCESS)),
                trace == null ? NONE : orNone(trace.elapsed(AgentEvalTrace.Stage.PLAN_MODEL)),
                trace == null ? NONE : orNone(trace.elapsed(AgentEvalTrace.Stage.PLAN_VALIDATE)),
                trace == null ? NONE : orNone(trace.elapsed(AgentEvalTrace.Stage.EXECUTE)),
                trace == null ? NONE : orNone(trace.elapsed(AgentEvalTrace.Stage.ANSWER_MODEL)),
                trace == null ? NONE : trace.unattributedMillis(),
                trace == null ? NONE : orNone(trace.visibleCapabilityCount()),
                trace == null ? NONE : orNone(trace.planningPromptChars()),
                trace == null ? NONE : orNone(trace.historyTurns()),
                trace == null ? NONE : orNone(trace.memoryCount()),
                trace == null ? NONE : orNone(trace.questionChars()),
                trace == null ? NONE : orNone(trace.plannedCallCount()),
                trace == null ? NONE : trace.modelCallCount(),
                trace == null ? NONE : orNone(trace.planPromptTokenCount()),
                trace == null ? NONE : orNone(trace.planCompletionTokenCount()),
                trace == null ? NONE : orNone(trace.answerPromptTokenCount()),
                trace == null ? NONE : orNone(trace.answerCompletionTokenCount()));
    }

    /**
     * 记一次模型调用。
     *
     * <p>{@code connection} 固定为 {@code NEW_CLIENT}：当前每次调用都新建 HTTP Client，没有连接复用，
     * P1a 复用连接后再区分冷热。只记长度与计数，不记提示词和返回内容。</p>
     */
    public void recordModelCall(ModelCall call) {
        log.info(
                "agent_eval_model correlationId={} stage={} outcome={} failureCategory={} httpStatus={} "
                        + "latencyMs={} requestChars={} promptTokenCount={} completionTokenCount={} model={} connection=NEW_CLIENT",
                call.correlationId(),
                call.stage(),
                call.outcome(),
                orNone(call.failureCategory()),
                orNone(call.httpStatus()),
                call.latencyMs(),
                call.requestChars(),
                orNone(call.promptTokenCount()),
                orNone(call.completionTokenCount()),
                call.model());
    }

    /**
     * 记一项能力调用。
     *
     * <p>失败原因是自由文本，可能夹带业务内容，所以只记成功与否，不记原因。
     * 复核与调用耗时分开，便于区分授权开销与下游执行开销。</p>
     */
    public void recordCapabilityCall(CapabilityCall call) {
        log.info(
                "agent_eval_call correlationId={} seq={} capability={} location={} outcome={} "
                        + "recheckMs={} invokeMs={} rowCount={} truncated={}",
                call.correlationId(),
                call.seq(),
                call.capabilityCode(),
                call.location(),
                call.outcome(),
                orNone(call.recheckMs()),
                orNone(call.invokeMs()),
                orNone(call.rowCount()),
                call.truncated());
    }

    /**
     * 记一轮会话的外层耗时，并把消息、客户端请求号与 {@code correlationId} 关联起来。
     *
     * <p>{@code agent.ask()} 之外的会话处理（占用租约、读取历史与记忆、写回结果）不在任务级事件的
     * 计时范围内；没有这条记录，分阶段明细就对不上用户看到的那条消息。{@code requestId} 是客户端生成的
     * 去重号，不含提问内容。失败时 {@code correlationId} 可能为空。</p>
     */
    public void recordTurn(Turn turn) {
        log.info(
                "agent_eval_turn messageId={} requestId={} correlationId={} outcome={} "
                        + "beginMs={} loadContextMs={} askMs={} finishMs={} totalMs={}",
                turn.messageId(),
                turn.requestId(),
                orNone(turn.correlationId()),
                turn.outcome(),
                turn.beginMs(),
                orNone(turn.loadContextMs()),
                orNone(turn.askMs()),
                orNone(turn.finishMs()),
                turn.totalMs());
    }

    private static final String NONE = "-";

    private static Object orNone(Object value) {
        return value == null ? NONE : value;
    }

    /**
     * @param paramKeys 只有键名，没有取值
     * @param validationResult 通过，或失败的规则编号
     * @param crossProjectCount 本次涉及的项目数，用来回答「跨项目聚合到底有没有人用」
     */
    public record Event(
            String correlationId,
            List<String> capabilityCodes,
            List<String> paramKeys,
            String validationResult,
            String outcome,
            int crossProjectCount,
            long latencyMs,
            Long promptTokenCount,
            Long completionTokenCount,
            String model) {}

    /**
     * 一次模型调用的记录。
     *
     * @param stage 规划或总结，取 {@link AgentEvalTrace.ModelStage} 名称
     * @param outcome {@code OK}、失败时的 {@code FAILED}，或模型已返回但计划被拒的 {@code PLAN_REJECTED}
     * @param failureCategory 失败类别，来自 {@code ModelCallFailure.Category}；成功时为空
     * @param httpStatus 模型服务返回的状态码；没有拿到响应时为空
     * @param requestChars 系统提示词与用户提示词的字符数之和
     */
    public record ModelCall(
            String correlationId,
            String stage,
            String outcome,
            String failureCategory,
            Integer httpStatus,
            long latencyMs,
            int requestChars,
            Long promptTokenCount,
            Long completionTokenCount,
            String model) {}

    /**
     * 一项能力调用的记录。
     *
     * @param seq 在本次计划中的序号，从 1 开始
     * @param location {@code LOCAL}（System 本地能力）或 {@code REMOTE}（业务项目注册能力）
     * @param outcome {@code OK}、{@code FAILED}（能力返回失败）或 {@code REJECTED}（复核未通过）
     * @param recheckMs 执行前权限复核耗时
     * @param invokeMs 能力调用耗时；复核未通过时为空
     * @param rowCount 返回行数；失败时为空
     */
    public record CapabilityCall(
            String correlationId,
            int seq,
            String capabilityCode,
            String location,
            String outcome,
            Long recheckMs,
            Long invokeMs,
            Integer rowCount,
            boolean truncated) {}

    /**
     * 一轮会话的外层耗时。
     *
     * @param outcome {@code OK}、{@code WRITE_CONFLICT}（写回时会话已更新）或 {@code FAILED}（抛出异常）
     * @param beginMs 占用租约并登记请求的耗时
     * @param loadContextMs 读取会话、记忆与历史的耗时
     * @param askMs 调用 {@code agent.ask()} 的耗时
     * @param finishMs 写回结果的耗时
     */
    public record Turn(
            String messageId,
            String requestId,
            String correlationId,
            String outcome,
            long beginMs,
            Long loadContextMs,
            Long askMs,
            Long finishMs,
            long totalMs) {}
}
