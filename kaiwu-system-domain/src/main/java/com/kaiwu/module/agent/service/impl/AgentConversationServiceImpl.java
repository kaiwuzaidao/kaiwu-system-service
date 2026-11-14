package com.kaiwu.module.agent.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.audit.EvaluationRecorder;
import com.kaiwu.module.agent.dto.AgentMessageRequest;
import com.kaiwu.module.agent.service.AgentConversationService;
import com.kaiwu.module.agent.service.AgentService;
import com.kaiwu.module.agent.store.AgentConversationStore;
import com.kaiwu.module.agent.vo.*;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** Server-owned conversation context; browser history is never trusted for persisted sessions. */
@Service("agentConversationService")
public class AgentConversationServiceImpl implements AgentConversationService {
    private final AgentConversationStore store;
    private final AgentService agent;
    private final EvaluationRecorder evaluations;

    public AgentConversationServiceImpl(AgentConversationStore store, AgentService agent) {
        this(store, agent, new EvaluationRecorder());
    }

    @Autowired
    public AgentConversationServiceImpl(
            AgentConversationStore store, AgentService agent, EvaluationRecorder evaluations) {
        this.store = store;
        this.agent = agent;
        this.evaluations = evaluations;
    }

    @Override
    public AgentMessageResult ask(
            String id, AgentMessageRequest request, KaiwuContext actor, RequestMetadata metadata) {
        long startedNanos = System.nanoTime();
        String userId = actor.userId();
        // Claim before reading settings/history so concurrent settings updates cannot race the turn.
        String messageId = store.begin(userId, id, request);
        long beginMs = elapsedMillis(startedNanos);
        Long loadContextMs = null;
        Long askMs = null;
        Long finishMs = null;
        String correlationId = null;
        String outcome = "FAILED";
        try {
            long loadStarted = System.nanoTime();
            var conversation = store.owned(userId, id);
            List<String> preferences = Boolean.TRUE.equals(conversation.getUseMemory())
                    ? store.memories(userId).stream()
                            .filter(AgentMemoryView::enabled)
                            .map(AgentMemoryView::content)
                            .toList()
                    : List.of();
            var history = store.history(userId, id);
            loadContextMs = elapsedMillis(loadStarted);

            long askStarted = System.nanoTime();
            var answer = agent.ask(request.question(), history, request.input(), preferences, actor, metadata);
            askMs = elapsedMillis(askStarted);
            correlationId = answer.correlationId();

            String text = answer.answer();
            if (answer.pendingAction() != null || answer.pendingRemoteAction() != null)
                text = "已生成操作预览。历史记录不保留确认凭据，也不代表操作已执行；请重新查询实际状态。";
            long finishStarted = System.nanoTime();
            boolean saved = store.finish(userId, id, messageId, AgentConversationStore.truncate(text, 20000), true);
            finishMs = elapsedMillis(finishStarted);
            if (!saved) {
                outcome = "WRITE_CONFLICT";
                throw new ApiException(HttpStatus.CONFLICT, "会话已更新，请重新加载历史", "api.agent.conversationBusy");
            }
            outcome = "OK";
            return new AgentMessageResult(messageId, answer);
        } catch (RuntimeException failure) {
            store.finish(userId, id, messageId, null, false);
            throw failure;
        } finally {
            evaluations.recordTurn(new EvaluationRecorder.Turn(
                    messageId,
                    request.requestId(),
                    correlationId,
                    outcome,
                    beginMs,
                    loadContextMs,
                    askMs,
                    finishMs,
                    elapsedMillis(startedNanos)));
        }
    }

    private static long elapsedMillis(long startedNanos) {
        return (System.nanoTime() - startedNanos) / 1_000_000;
    }
}
