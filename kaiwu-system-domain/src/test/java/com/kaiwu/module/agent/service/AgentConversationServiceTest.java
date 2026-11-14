package com.kaiwu.module.agent.service;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.audit.EvaluationRecorder;
import com.kaiwu.module.agent.controller.AgentConversationController;
import com.kaiwu.module.agent.dto.*;
import com.kaiwu.module.agent.entity.AgentConversationEntity;
import com.kaiwu.module.agent.service.impl.AgentConversationServiceImpl;
import com.kaiwu.module.agent.store.AgentConversationStore;
import com.kaiwu.module.agent.vo.*;
import com.kaiwu.starter.KaiwuContext;
import com.kaiwu.starter.RequirePermission;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;

class AgentConversationServiceTest {
    private final AgentConversationStore store = mock(AgentConversationStore.class);
    private final AgentService agent = mock(AgentService.class);
    private final AgentConversationService service = new AgentConversationServiceImpl(store, agent);
    private final KaiwuContext actor = new KaiwuContext(
            "1",
            "session",
            null,
            null,
            Set.of("system:agent:ask"),
            Set.of(),
            "v1",
            "kaiwu-system-service",
            Instant.now(),
            Instant.now().plusSeconds(60),
            "context");
    private final RequestMetadata metadata = new RequestMetadata("127.0.0.1", "test");
    private final AgentMessageRequest request = new AgentMessageRequest("继续查询", "request-identifier-123", null);

    private void setup(boolean useMemory) {
        var conversation = new AgentConversationEntity();
        conversation.setUseMemory(useMemory);
        when(store.begin("1", "2", request)).thenReturn("3");
        when(store.owned("1", "2")).thenReturn(conversation);
        when(store.history("1", "2")).thenReturn(List.of(new AgentConversationTurn("此前问题", "此前答复")));
        when(store.finish(eq("1"), eq("2"), eq("3"), any(), anyBoolean())).thenReturn(true);
    }

    @Test
    void usesOnlyEnabledOwnedMemoryAndServerHistory() {
        setup(true);
        when(store.memories("1"))
                .thenReturn(List.of(
                        new AgentMemoryView("4", "按周汇总", true, LocalDateTime.now()),
                        new AgentMemoryView("5", "停用内容", false, LocalDateTime.now())));
        var answer = new AgentAnswerView("文本答复", List.of(), List.of(), "c", null);
        when(agent.ask(eq(request.question()), anyList(), isNull(), eq(List.of("按周汇总")), eq(actor), eq(metadata)))
                .thenReturn(answer);
        assertThat(service.ask("2", request, actor, metadata).answer()).isEqualTo(answer);
        verify(agent)
                .ask(
                        eq(request.question()),
                        eq(List.of(new AgentConversationTurn("此前问题", "此前答复"))),
                        isNull(),
                        eq(List.of("按周汇总")),
                        eq(actor),
                        eq(metadata));
        verify(store).finish("1", "2", "3", "文本答复", true);
    }

    @Test
    void disablingMemoryDoesNotEvenLoadItAndFailureIsNotPersistedVerbatim() {
        setup(false);
        when(agent.ask(anyString(), anyList(), isNull(), eq(List.of()), eq(actor), eq(metadata)))
                .thenThrow(new IllegalStateException("internal secret"));
        assertThatThrownBy(() -> service.ask("2", request, actor, metadata)).isInstanceOf(IllegalStateException.class);
        verify(store, never()).memories(anyString());
        verify(store).finish("1", "2", "3", null, false);
    }

    @Test
    void forbiddenOrDuplicateConversationNeverReachesModel() {
        when(store.begin("1", "2", request)).thenThrow(new IllegalStateException("denied"));
        assertThatThrownBy(() -> service.ask("2", request, actor, metadata)).isInstanceOf(IllegalStateException.class);
        verifyNoInteractions(agent);
    }

    @Test
    void previewsPersistOnlyNonExecutableTextNeverTokensOrRawCards() {
        setup(false);
        var preview = mock(AgentActionView.class);
        when(preview.confirmationToken()).thenReturn("must-not-be-stored");
        var answer = new AgentAnswerView("", List.of(), List.of(), "trace", null, preview);
        when(agent.ask(anyString(), anyList(), isNull(), eq(List.of()), eq(actor), eq(metadata)))
                .thenReturn(answer);
        assertThat(service.ask("2", request, actor, metadata)
                        .answer()
                        .pendingAction()
                        .confirmationToken())
                .isEqualTo("must-not-be-stored");
        var saved = org.mockito.ArgumentCaptor.forClass(String.class);
        verify(store).finish(eq("1"), eq("2"), eq("3"), saved.capture(), eq(true));
        assertThat(saved.getValue()).contains("不保留确认凭据").doesNotContain("must-not-be-stored");
    }

    @Test
    void personalEndpointsAllRequireAgentPermission() {
        var methods = java.util.Arrays.stream(AgentConversationController.class.getDeclaredMethods())
                .filter(m -> java.lang.reflect.Modifier.isPublic(m.getModifiers()))
                .toList();
        assertThat(methods).hasSize(11);
        for (var method : methods)
            assertThat(method.getAnnotation(RequirePermission.class).value()).isEqualTo("system:agent:ask");
    }

    private static final class TurnRecorder extends EvaluationRecorder {
        final List<EvaluationRecorder.Turn> turns = new java.util.ArrayList<>();

        @Override
        public void recordTurn(EvaluationRecorder.Turn turn) {
            turns.add(turn);
            super.recordTurn(turn);
        }
    }

    /** 外层耗时把消息、客户端请求号与 correlationId 关联起来，且不含提问和答复内容。 */
    @Test
    void turnRecordLinksMessageRequestAndCorrelationWithoutContent() {
        setup(false);
        var recorder = new TurnRecorder();
        var timed = new AgentConversationServiceImpl(store, agent, recorder);
        when(agent.ask(anyString(), anyList(), isNull(), anyList(), eq(actor), eq(metadata)))
                .thenReturn(new AgentAnswerView("文本答复", List.of(), List.of(), "corr-1", null));

        timed.ask("2", request, actor, metadata);

        assertThat(recorder.turns).singleElement().satisfies(turn -> {
            assertThat(turn.messageId()).isEqualTo("3");
            assertThat(turn.requestId()).isEqualTo("request-identifier-123");
            assertThat(turn.correlationId()).isEqualTo("corr-1");
            assertThat(turn.outcome()).isEqualTo("OK");
            assertThat(turn.loadContextMs()).isNotNull();
            assertThat(turn.askMs()).isNotNull();
            assertThat(turn.finishMs()).isNotNull();
            assertThat(turn.totalMs()).isGreaterThanOrEqualTo(turn.beginMs());
            assertThat(turn.toString()).doesNotContain("继续查询").doesNotContain("文本答复");
        });
    }

    /** 失败路径也记一条，且仍把消息标为失败；correlationId 此时未知。 */
    @Test
    void failedTurnIsStillRecordedAndStillMarkedFailed() {
        setup(false);
        var recorder = new TurnRecorder();
        var timed = new AgentConversationServiceImpl(store, agent, recorder);
        when(agent.ask(anyString(), anyList(), isNull(), anyList(), eq(actor), eq(metadata)))
                .thenThrow(new IllegalStateException("internal secret"));

        assertThatThrownBy(() -> timed.ask("2", request, actor, metadata)).isInstanceOf(IllegalStateException.class);

        verify(store).finish("1", "2", "3", null, false);
        assertThat(recorder.turns).singleElement().satisfies(turn -> {
            assertThat(turn.outcome()).isEqualTo("FAILED");
            assertThat(turn.correlationId()).isNull();
            assertThat(turn.askMs()).isNull();
            assertThat(turn.finishMs()).isNull();
        });
    }

    /** 写回时会话已更新：对外仍是原来的冲突错误，消息仍被标记失败，外层记录为 WRITE_CONFLICT。 */
    @Test
    void writeConflictKeepsOriginalBehaviourAndIsRecorded() {
        setup(false);
        when(store.finish(eq("1"), eq("2"), eq("3"), any(), eq(true))).thenReturn(false);
        var recorder = new TurnRecorder();
        var timed = new AgentConversationServiceImpl(store, agent, recorder);
        when(agent.ask(anyString(), anyList(), isNull(), anyList(), eq(actor), eq(metadata)))
                .thenReturn(new AgentAnswerView("文本答复", List.of(), List.of(), "corr-2", null));

        assertThatThrownBy(() -> timed.ask("2", request, actor, metadata))
                .isInstanceOf(com.kaiwu.common.ApiException.class);

        verify(store).finish("1", "2", "3", null, false);
        assertThat(recorder.turns).singleElement().satisfies(turn -> {
            assertThat(turn.outcome()).isEqualTo("WRITE_CONFLICT");
            assertThat(turn.correlationId()).isEqualTo("corr-2");
        });
    }
}
