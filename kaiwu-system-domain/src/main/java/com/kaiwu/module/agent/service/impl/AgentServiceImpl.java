package com.kaiwu.module.agent.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.audit.AgentEvalTrace;
import com.kaiwu.module.agent.audit.EvaluationRecorder;
import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.agent.dto.AgentConversationTurn;
import com.kaiwu.module.agent.execution.AccessReChecker;
import com.kaiwu.module.agent.execution.CapabilityInvoker;
import com.kaiwu.module.agent.execution.RemoteWriteActionCoordinator;
import com.kaiwu.module.agent.planning.AgentPlan;
import com.kaiwu.module.agent.planning.AgentPlanValidator;
import com.kaiwu.module.agent.planning.AgentPlanner;
import com.kaiwu.module.agent.planning.AgentPromptBuilder;
import com.kaiwu.module.agent.planning.ExplicitReadIntentGuard;
import com.kaiwu.module.agent.planning.ExplicitWriteIntentGuard;
import com.kaiwu.module.agent.planning.PlanRejectedException;
import com.kaiwu.module.agent.presentation.AgentCardNavigation;
import com.kaiwu.module.agent.presentation.AgentCardPolicy;
import com.kaiwu.module.agent.presentation.CardProjection;
import com.kaiwu.module.agent.presentation.ModelProjection;
import com.kaiwu.module.agent.presentation.ResultProjector;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.CapabilityResult;
import com.kaiwu.module.agent.protocol.OutputViewSpec;
import com.kaiwu.module.agent.service.AgentActionService;
import com.kaiwu.module.agent.service.AgentRateLimiter;
import com.kaiwu.module.agent.service.AgentService;
import com.kaiwu.module.agent.vo.AgentAnswerView;
import com.kaiwu.module.agent.vo.AgentCardView;
import com.kaiwu.module.agent.vo.AgentLocalCapabilityView;
import com.kaiwu.module.identity.repository.AuthRepository;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.ModelCallFailure;
import com.kaiwu.starter.KaiwuContext;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * 一次提问的完整编排。
 *
 * <p>步骤顺序是安全要求，不是风格问题：<b>权限裁剪必须发生在接触模型之前</b>
 * ——先给模型再过滤等于把目录泄露给它，也给了它「建议你去申请权限」这类越界输出的
 * 机会；<b>执行前必须重新鉴权</b>——规划与执行之间成员关系可能刚被撤销
 * （ADR 0030 第 4、5 条）。</p>
 */
@Service("agentService")
public class AgentServiceImpl implements AgentService {

    private static AgentCardView.OutputView outputView(Capability capability) {
        var view = capability.outputView();
        if (view == null) return null;
        return new AgentCardView.OutputView(
                view.title(),
                view.fields().stream()
                        .map(field -> new AgentCardView.Field(
                                field.name(), field.label(), field.format().name(), field.dictCode()))
                        .toList());
    }

    private final CapabilityCatalog catalog;
    private final AgentPromptBuilder prompts;
    private final AgentPlanner planner;
    private final AgentPlanValidator validator;
    private final AccessReChecker accessReChecker;
    private final CapabilityInvoker invoker;
    private final ResultProjector projector;
    private final AgentRateLimiter rateLimiter;
    private final EvaluationRecorder evaluations;
    private final ProjectService projectService;
    private final AuthRepository authRepository;
    private final AuditPort audit;
    private final AgentActionService actions;
    private RemoteWriteActionCoordinator remoteActions;

    @SuppressWarnings("java:S107")
    public AgentServiceImpl(
            CapabilityCatalog catalog,
            AgentPromptBuilder prompts,
            AgentPlanner planner,
            AgentPlanValidator validator,
            AccessReChecker accessReChecker,
            CapabilityInvoker invoker,
            ResultProjector projector,
            AgentRateLimiter rateLimiter,
            EvaluationRecorder evaluations,
            ProjectService projectService,
            AuthRepository authRepository,
            AuditPort audit,
            AgentActionService actions) {
        this.catalog = catalog;
        this.prompts = prompts;
        this.planner = planner;
        this.validator = validator;
        this.accessReChecker = accessReChecker;
        this.invoker = invoker;
        this.projector = projector;
        this.rateLimiter = rateLimiter;
        this.evaluations = evaluations;
        this.projectService = projectService;
        this.authRepository = authRepository;
        this.audit = audit;
        this.actions = actions;
    }

    @org.springframework.beans.factory.annotation.Autowired
    public void remoteWriteActions(RemoteWriteActionCoordinator value) {
        this.remoteActions = value;
    }

    public AgentAnswerView ask(String question, KaiwuContext actor, RequestMetadata metadata) {
        return ask(question, List.of(), actor, metadata);
    }

    /** 展示全部已实现的本地能力与当前权限，不把未授权能力交给模型。 */
    public List<AgentLocalCapabilityView> localCapabilities(KaiwuContext actor) {
        if (actor == null || !actor.hasPermission("system:agent:ask")) {
            throw new ApiException(HttpStatus.FORBIDDEN, "无权使用 AI 助手", "api.common.forbidden");
        }
        return catalog.localCapabilities().stream()
                .map(capability -> new AgentLocalCapabilityView(
                        capability.code(),
                        capability.version(),
                        capability.description(),
                        capability.permission(),
                        capability.readOnly(),
                        actor.hasPermission(capability.permission())))
                .toList();
    }

    public AgentAnswerView ask(
            String question, List<AgentConversationTurn> history, KaiwuContext actor, RequestMetadata metadata) {
        return ask(question, history, null, actor, metadata);
    }

    public AgentAnswerView ask(
            String question,
            List<AgentConversationTurn> history,
            com.kaiwu.module.agent.dto.AgentInputSubmission input,
            KaiwuContext actor,
            RequestMetadata metadata) {
        return ask(question, history, input, List.of(), actor, metadata);
    }

    /** Personal preferences are untrusted data, never capability or permission grants. */
    public AgentAnswerView ask(
            String question,
            List<AgentConversationTurn> history,
            com.kaiwu.module.agent.dto.AgentInputSubmission input,
            List<String> preferences,
            KaiwuContext actor,
            RequestMetadata metadata) {
        String correlationId = UUID.randomUUID().toString();
        long startedAt = System.currentTimeMillis();
        AgentEvalTrace trace = new AgentEvalTrace(correlationId);
        trace.begin(AgentEvalTrace.Stage.PREPROCESS);

        if (!rateLimiter.tryAcquire(actor.userId())) {
            // 超限时不调用模型，也不记评估事件——它不反映能力表现。
            return degraded(correlationId, "RATE_LIMITED", 60);
        }

        // 1. 裁剪：必须在接触模型之前完成。
        List<Capability> visible;
        try {
            visible = accessReChecker.visibleTo(catalog.visibleTo(actor), actor);
        } catch (PlanRejectedException denied) {
            return rejected(actor, correlationId, denied, metadata, startedAt, trace, null);
        }
        if (visible.isEmpty()) {
            return rejected(
                    actor, correlationId, new PlanRejectedException(3, "无权限操作"), metadata, startedAt, trace, null);
        }
        if (ExplicitReadIntentGuard.denied(question, visible) || ExplicitWriteIntentGuard.denied(question, visible)) {
            return rejected(
                    actor, correlationId, new PlanRejectedException(3, "无权限操作"), metadata, startedAt, trace, null);
        }
        AgentPlanner.Target config = planner.requireProvider("PLAN");
        AgentPlanner.Target answerConfig = planner.requireProvider("ANSWER");
        Set<String> visibleProjects = visibleProjectIds(actor);

        // 2. 规划。
        String planningPrompt = prompts.planningSystemPrompt(visible, visibleProjects, preferences, history);
        trace.end(AgentEvalTrace.Stage.PREPROCESS);
        trace.scale(
                visible.size(),
                planningPrompt.length(),
                history == null ? 0 : history.size(),
                preferences == null ? 0 : preferences.size(),
                question == null ? 0 : question.length());
        AgentPlanner.Planned planned;
        AgentPlan plan;
        try {
            if (input != null) {
                if (visible.stream()
                        .noneMatch(capability ->
                                capability.code().equals(input.capabilityCode()) && capability.inputForm() != null))
                    throw new PlanRejectedException(3, "无权限操作");
                Map<String, Object> values = new LinkedHashMap<>();
                input.values().forEach((key, value) -> {
                    if (value != null && !(value instanceof String text && text.isBlank())) values.put(key, value);
                });
                planned = new AgentPlanner.Planned(
                        new AgentPlan(true, List.of(new AgentPlan.Call(input.capabilityCode(), values)), null), 0L, 0L);
            } else planned = timedPlan(config, planningPrompt, question, trace);
            trace.begin(AgentEvalTrace.Stage.PLAN_VALIDATE);
            try {
                plan = input == null
                        ? validator.validate(planned.plan(), actor, visibleProjects)
                        : validator.validateInput(planned.plan(), actor, visibleProjects);
            } finally {
                trace.end(AgentEvalTrace.Stage.PLAN_VALIDATE);
            }
            trace.plannedCalls(plan.calls().size());
        } catch (PlanRejectedException rejected) {
            return rejected(actor, correlationId, rejected, metadata, startedAt, trace, config.model());
        } catch (RuntimeException unavailable) {
            return unavailable(actor, correlationId, metadata, startedAt, trace, config.model());
        }

        if (!plan.understood()) {
            String reply = plan.clarification() == null ? "没有理解这个问题，可以换个说法吗？" : plan.clarification();
            recordAudit(actor, correlationId, "ASK_CLARIFY", null, metadata);
            evaluations.record(
                    new EvaluationRecorder.Event(
                            correlationId,
                            List.of(),
                            List.of(),
                            "PASSED",
                            "NOT_UNDERSTOOD",
                            0,
                            System.currentTimeMillis() - startedAt,
                            planned.promptTokens(),
                            planned.completionTokens(),
                            config.model()),
                    trace);
            if (plan.calls().size() == 1
                    && catalog.findVisible(plan.calls().getFirst().code(), actor)
                            .map(capability -> capability.inputForm() != null)
                            .orElse(false)) {
                var call = plan.calls().getFirst();
                try {
                    var capability = catalog.findVisible(call.code(), actor)
                            .orElseThrow(() -> new PlanRejectedException(3, "无权限操作"));
                    accessReChecker.check(capability, call.params(), actor);
                } catch (PlanRejectedException denied) {
                    return rejected(actor, correlationId, denied, metadata, startedAt, trace, config.model());
                }
                return new AgentAnswerView(
                        "请填写表单中的必填信息。",
                        List.of(),
                        List.of(),
                        correlationId,
                        null,
                        null,
                        null,
                        new com.kaiwu.module.agent.vo.AgentInputFormView(
                                call.code(),
                                call.params(),
                                catalog.findVisible(call.code(), actor)
                                        .orElseThrow()
                                        .inputForm()));
            }
            return new AgentAnswerView(reply, List.of(), List.of(), correlationId, null);
        }

        if (plan.calls().size() == 1
                && plan.calls().getFirst().code().startsWith("system.")
                && catalog.findVisible(plan.calls().getFirst().code(), actor)
                        .map(capability -> !capability.readOnly())
                        .orElse(false)) {
            try {
                var capability = catalog.findVisible(plan.calls().getFirst().code(), actor)
                        .orElseThrow(() -> new PlanRejectedException(3, "无权限操作"));
                accessReChecker.check(capability, plan.calls().getFirst().params(), actor);
            } catch (PlanRejectedException rejected) {
                return rejected(actor, correlationId, rejected, metadata, startedAt, trace, config.model());
            }
            var preview = actions.preview(plan.calls().getFirst(), actor, metadata);
            evaluations.record(
                    new EvaluationRecorder.Event(
                            correlationId,
                            List.of(plan.calls().getFirst().code()),
                            List.copyOf(plan.calls().getFirst().params().keySet()),
                            "PASSED",
                            "ACTION_PREVIEW",
                            0,
                            System.currentTimeMillis() - startedAt,
                            planned.promptTokens(),
                            planned.completionTokens(),
                            config.model()),
                    trace);
            return new AgentAnswerView("", List.of(), List.of(), correlationId, null, preview);
        }

        if (plan.calls().size() == 1) {
            AgentPlan.Call call = plan.calls().getFirst();
            try {
                Capability capability = catalog.findVisible(call.code(), actor)
                        .orElseThrow(() -> new PlanRejectedException(3, "无权限操作"));
                if (!capability.readOnly() && !Capability.SYSTEM_PROJECT_CODE.equals(capability.projectCode())) {
                    accessReChecker.check(capability, call.params(), actor);
                    var preview = remoteActions.preview(call, actor, metadata, correlationId);
                    evaluations.record(
                            new EvaluationRecorder.Event(
                                    correlationId,
                                    List.of(capability.code()),
                                    List.copyOf(call.params().keySet()),
                                    "PASSED",
                                    "ACTION_PREVIEW",
                                    1,
                                    System.currentTimeMillis() - startedAt,
                                    planned.promptTokens(),
                                    planned.completionTokens(),
                                    config.model()),
                            trace);
                    return new AgentAnswerView("", List.of(), List.of(), correlationId, null, null, preview);
                }
            } catch (PlanRejectedException rejected) {
                return rejected(actor, correlationId, rejected, metadata, startedAt, trace, config.model());
            } catch (RuntimeException unavailable) {
                return unavailable(actor, correlationId, metadata, startedAt, trace, config.model());
            }
        }

        // 3. 执行：逐条复核后调用，单条失败不拖垮整体。
        List<AgentCardView> cards = new ArrayList<>();
        Map<String, ModelProjection> modelResults = new LinkedHashMap<>();
        Map<String, OutputViewSpec> modelViews = new LinkedHashMap<>();
        Map<String, String> modelProjects = new LinkedHashMap<>();
        List<String> usedCapabilities = new ArrayList<>();
        List<String> paramKeys = new ArrayList<>();
        Set<String> touchedProjects = new LinkedHashSet<>();
        boolean partialFailure = false;
        boolean truncated = false;

        int seq = 0;
        trace.begin(AgentEvalTrace.Stage.EXECUTE);
        try {
            for (AgentPlan.Call call : plan.calls()) {
                seq++;
                Capability capability = catalog.findVisible(call.code(), actor)
                        .orElseThrow(() -> new PlanRejectedException(3, "无权限操作"));
                String location = Capability.SYSTEM_PROJECT_CODE.equals(capability.projectCode()) ? "LOCAL" : "REMOTE";
                long recheckStarted = System.nanoTime();
                try {
                    accessReChecker.check(capability, call.params(), actor);
                } catch (PlanRejectedException denied) {
                    evaluations.recordCapabilityCall(new EvaluationRecorder.CapabilityCall(
                            correlationId,
                            seq,
                            capability.code(),
                            location,
                            "REJECTED",
                            elapsedMillis(recheckStarted),
                            null,
                            null,
                            false));
                    throw denied;
                }
                long recheckMs = elapsedMillis(recheckStarted);

                long invokeStarted = System.nanoTime();
                CapabilityResult result = invoker.invoke(capability, call.params(), actor, correlationId);
                long invokeMs = elapsedMillis(invokeStarted);
                usedCapabilities.add(capability.code());
                paramKeys.addAll(call.params().keySet());
                touchedProjects.addAll(result.sourceProjects());

                if (!result.succeeded()) {
                    partialFailure = true;
                    evaluations.recordCapabilityCall(new EvaluationRecorder.CapabilityCall(
                            correlationId,
                            seq,
                            capability.code(),
                            location,
                            "FAILED",
                            recheckMs,
                            invokeMs,
                            null,
                            false));
                    recordAudit(actor, correlationId, "CAPABILITY_FAILED", capability.code(), metadata);
                    continue;
                }
                ModelProjection projection = projector.toModel(capability, result.rows());
                truncated = truncated || projection.truncated();
                evaluations.recordCapabilityCall(new EvaluationRecorder.CapabilityCall(
                        correlationId,
                        seq,
                        capability.code(),
                        location,
                        "OK",
                        recheckMs,
                        invokeMs,
                        result.rows().size(),
                        projection.truncated()));
                modelResults.put(capability.code(), projection);
                if (!Capability.SYSTEM_PROJECT_CODE.equals(capability.projectCode())
                        && result.sourceProjects().size() == 1) {
                    modelProjects.put(capability.code(), result.sourceProjects().getFirst());
                }
                if (capability.outputView() != null) modelViews.put(capability.code(), capability.outputView());

                if (AgentCardPolicy.showDetails(question)) {
                    CardProjection card =
                            projector.toCard(capability, result.title(), result.rows(), result.sourceProjects());
                    cards.add(new AgentCardView(
                            card.type().name().toLowerCase(java.util.Locale.ROOT),
                            capability.code(),
                            card.title(),
                            card.rows(),
                            card.dataAt(),
                            outputView(capability),
                            AgentCardNavigation.build(
                                    capability, call.params(), card.rows(), projection.truncated(), visible)));
                }
                recordAudit(actor, correlationId, "CAPABILITY_CALLED", capability.code(), metadata);
            }
        } catch (PlanRejectedException rejected) {
            return rejected(actor, correlationId, rejected, metadata, startedAt, trace, config.model());
        }
        trace.end(AgentEvalTrace.Stage.EXECUTE);

        // 4. 总结。
        String answerLocale = localeOf(actor);
        String answerPrompt = prompts.answerSystemPrompt(answerLocale, preferences, history);
        AgentPlanner.Answered answered;
        try {
            answered = timedAnswer(
                    answerConfig,
                    answerPrompt,
                    prompts.answerUserPrompt(
                            question, modelResults, modelViews, modelProjects, actor.userId(), truncated, answerLocale),
                    trace);
        } catch (RuntimeException unavailable) {
            return unavailable(actor, correlationId, metadata, startedAt, trace, config.model());
        }

        recordAudit(actor, correlationId, "ASK", "capabilities=" + usedCapabilities, metadata);
        evaluations.record(
                new EvaluationRecorder.Event(
                        correlationId,
                        usedCapabilities,
                        paramKeys,
                        "PASSED",
                        partialFailure ? "PARTIAL_CAPABILITY_FAILURE" : "SUCCESS",
                        touchedProjects.size(),
                        System.currentTimeMillis() - startedAt,
                        sum(planned.promptTokens(), answered.promptTokens()),
                        sum(planned.completionTokens(), answered.completionTokens()),
                        config.model()),
                trace);

        return new AgentAnswerView(
                answered.content(),
                cards,
                usedCapabilities,
                correlationId,
                partialFailure ? new AgentAnswerView.Degraded("PARTIAL_CAPABILITY_FAILURE", null) : null);
    }

    private Set<String> visibleProjectIds(KaiwuContext actor) {
        Set<String> ids = new LinkedHashSet<>();
        projectService.currentProjects(actor.userId()).forEach(project -> ids.add(project.id()));
        return ids;
    }

    /** 答复语言的权威来源是服务端账号设置，不接受前端传入。 */
    private String localeOf(KaiwuContext actor) {
        return authRepository
                .findUserById(actor.userId())
                .map(AuthRepository.UserAccount::locale)
                .orElse("zh-CN");
    }

    /** 审计：一条请求父记录 + 每个能力调用一条子记录，共享同一 correlationId。 */
    private void recordAudit(
            KaiwuContext actor, String correlationId, String operation, String detail, RequestMetadata metadata) {
        String text =
                detail == null ? "correlationId=" + correlationId : "correlationId=" + correlationId + " " + detail;
        audit.recordOperation(actor, "agent", operation, "/api/agent/ask", text, metadata);
    }

    private AgentAnswerView degraded(String correlationId, String reason, Integer retryAfter) {
        return new AgentAnswerView(
                "请求过于频繁，请稍后再试。", List.of(), List.of(), correlationId, new AgentAnswerView.Degraded(reason, retryAfter));
    }

    private AgentAnswerView rejected(
            KaiwuContext actor,
            String correlationId,
            PlanRejectedException rejected,
            RequestMetadata metadata,
            long startedAt,
            AgentEvalTrace trace,
            String model) {
        trace.endOpen();
        recordAudit(actor, correlationId, "ASK_REJECTED", "rule=" + rejected.rule(), metadata);
        evaluations.record(
                new EvaluationRecorder.Event(
                        correlationId,
                        List.of(),
                        List.of(),
                        "REJECTED_RULE_" + rejected.rule(),
                        "PLAN_INVALID",
                        0,
                        System.currentTimeMillis() - startedAt,
                        null,
                        null,
                        model),
                trace);
        return new AgentAnswerView(
                rejected.getMessage(),
                List.of(),
                List.of(),
                correlationId,
                new AgentAnswerView.Degraded("PLAN_INVALID", null));
    }

    private AgentAnswerView unavailable(
            KaiwuContext actor,
            String correlationId,
            RequestMetadata metadata,
            long startedAt,
            AgentEvalTrace trace,
            String model) {
        trace.endOpen();
        recordAudit(actor, correlationId, "ASK_PROVIDER_FAILED", null, metadata);
        evaluations.record(
                new EvaluationRecorder.Event(
                        correlationId,
                        List.of(),
                        List.of(),
                        "PASSED",
                        "PROVIDER_UNAVAILABLE",
                        0,
                        System.currentTimeMillis() - startedAt,
                        null,
                        null,
                        model),
                trace);
        return new AgentAnswerView(
                "当前无法连接大模型服务，请稍后重试。",
                List.of(),
                List.of(),
                correlationId,
                new AgentAnswerView.Degraded("PROVIDER_UNAVAILABLE", 30));
    }

    /**
     * 调用规划模型并记录一条模型调用事件。
     *
     * <p>模型已返回但计划被拒（{@link PlanRejectedException}）与模型调用本身失败分开记：前者是
     * 提示词或模型的问题，后者是网络或服务商的问题。两者都原样抛出，不改变编排的降级行为。</p>
     */
    private AgentPlanner.Planned timedPlan(
            AgentPlanner.Target config, String systemPrompt, String question, AgentEvalTrace trace) {
        long started = System.nanoTime();
        int requestChars = systemPrompt.length() + question.length();
        trace.begin(AgentEvalTrace.Stage.PLAN_MODEL);
        try {
            AgentPlanner.Planned planned = planner.plan(config, systemPrompt, question);
            trace.modelCalled(AgentEvalTrace.ModelStage.PLAN, planned.promptTokens(), planned.completionTokens());
            evaluations.recordModelCall(modelCall(
                    trace,
                    AgentEvalTrace.ModelStage.PLAN,
                    "OK",
                    null,
                    started,
                    requestChars,
                    planned.promptTokens(),
                    planned.completionTokens(),
                    config));
            return planned;
        } catch (PlanRejectedException rejected) {
            trace.modelCalled(AgentEvalTrace.ModelStage.PLAN, null, null);
            evaluations.recordModelCall(modelCall(
                    trace,
                    AgentEvalTrace.ModelStage.PLAN,
                    "PLAN_REJECTED",
                    null,
                    started,
                    requestChars,
                    null,
                    null,
                    config));
            throw rejected;
        } catch (RuntimeException failure) {
            trace.modelCallFailed();
            evaluations.recordModelCall(modelCall(
                    trace,
                    AgentEvalTrace.ModelStage.PLAN,
                    "FAILED",
                    failure,
                    started,
                    requestChars,
                    null,
                    null,
                    config));
            throw failure;
        } finally {
            trace.end(AgentEvalTrace.Stage.PLAN_MODEL);
        }
    }

    /** 调用总结模型并记录一条模型调用事件；失败原样抛出。 */
    private AgentPlanner.Answered timedAnswer(
            AgentPlanner.Target config, String systemPrompt, String userPrompt, AgentEvalTrace trace) {
        long started = System.nanoTime();
        int requestChars = systemPrompt.length() + userPrompt.length();
        trace.begin(AgentEvalTrace.Stage.ANSWER_MODEL);
        try {
            AgentPlanner.Answered answered = planner.answer(config, systemPrompt, userPrompt);
            trace.modelCalled(AgentEvalTrace.ModelStage.ANSWER, answered.promptTokens(), answered.completionTokens());
            evaluations.recordModelCall(modelCall(
                    trace,
                    AgentEvalTrace.ModelStage.ANSWER,
                    "OK",
                    null,
                    started,
                    requestChars,
                    answered.promptTokens(),
                    answered.completionTokens(),
                    config));
            return answered;
        } catch (RuntimeException failure) {
            trace.modelCallFailed();
            evaluations.recordModelCall(modelCall(
                    trace,
                    AgentEvalTrace.ModelStage.ANSWER,
                    "FAILED",
                    failure,
                    started,
                    requestChars,
                    null,
                    null,
                    config));
            throw failure;
        } finally {
            trace.end(AgentEvalTrace.Stage.ANSWER_MODEL);
        }
    }

    private static EvaluationRecorder.ModelCall modelCall(
            AgentEvalTrace trace,
            AgentEvalTrace.ModelStage stage,
            String outcome,
            RuntimeException failure,
            long startedNanos,
            int requestChars,
            Long promptTokens,
            Long completionTokens,
            AgentPlanner.Target config) {
        return new EvaluationRecorder.ModelCall(
                trace.correlationId(),
                stage.name(),
                outcome,
                failure == null ? null : ModelCallFailure.categoryOf(failure).name(),
                failure == null ? null : ModelCallFailure.statusOf(failure),
                elapsedMillis(startedNanos),
                requestChars,
                promptTokens,
                completionTokens,
                config.model());
    }

    private static long elapsedMillis(long startedNanos) {
        return (System.nanoTime() - startedNanos) / 1_000_000;
    }

    private static Long sum(Long left, Long right) {
        if (left == null) {
            return right;
        }
        return right == null ? left : left + right;
    }
}
