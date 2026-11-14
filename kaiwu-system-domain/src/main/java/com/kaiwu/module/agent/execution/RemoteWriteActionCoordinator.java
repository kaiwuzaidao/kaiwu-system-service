package com.kaiwu.module.agent.execution;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.catalog.RemoteCapabilitySource;
import com.kaiwu.module.agent.planning.AgentPlan;
import com.kaiwu.module.agent.planning.PlanRejectedException;
import com.kaiwu.module.agent.service.AgentRemoteActionService;
import com.kaiwu.module.agent.vo.AgentRemoteActionView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.starter.KaiwuContext;
import java.nio.charset.StandardCharsets;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.json.JsonMapper;

/** 预览来自真实业务 Handler；确认后只发一次 EXECUTE，未知结果只发 RESULT。 */
@Service
public class RemoteWriteActionCoordinator {
    private static final Logger LOG = LoggerFactory.getLogger(RemoteWriteActionCoordinator.class);
    private static final JsonMapper JSON = JsonMapper.builder()
            .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
            .enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION)
            .build();

    private final RemoteCapabilitySource source;
    private final AgentRemoteActionService actions;
    private final RemoteWriteTransport transport;
    private final AuditPort audit;

    public RemoteWriteActionCoordinator(
            RemoteCapabilitySource source,
            AgentRemoteActionService actions,
            RemoteWriteTransport transport,
            AuditPort audit) {
        this.source = source;
        this.actions = actions;
        this.transport = transport;
        this.audit = audit;
    }

    /** 只能从已通过 AgentPlanValidator 的单项写计划调用。 */
    public AgentRemoteActionView preview(
            AgentPlan.Call call, KaiwuContext actor, RequestMetadata metadata, String correlationId) {
        var approved = source.visibleWriteRevision(call.code(), actor);
        String paramsJson = JSON.writeValueAsString(call.params());
        if (paramsJson.getBytes(StandardCharsets.UTF_8).length > 16_384) throw new PlanRejectedException(6, "写操作参数过长");
        byte[] response = transport.send(new RemoteWriteTransport.Request(
                actor.sessionId(),
                "PREVIEW",
                call.code(),
                approved.capability().version(),
                approved.manifestHash(),
                paramsJson,
                null,
                null,
                null,
                null,
                correlationId));
        var tree = JSON.readTree(response);
        if (tree == null || !tree.isObject() || !tree.path("preconditionsJson").isString())
            throw new IllegalStateException("Agent preview unavailable");
        String previewJson = new String(response, StandardCharsets.UTF_8);
        var pending = actions.prepare(
                call.code(),
                approved.capability().version(),
                approved.manifestHash(),
                paramsJson,
                tree.path("preconditionsJson").asString(),
                previewJson,
                correlationId,
                actor);
        recordAudit(actor, "ACTION_PREVIEW", pending.actionId(), call.code(), metadata);
        return new AgentRemoteActionView(
                pending.actionId(),
                approved.access().projectId(),
                approved.access().projectCode(),
                call.code(),
                approved.capability().description(),
                approved.capability().version(),
                "PENDING",
                approved.confirmation().name(),
                pending.preview().displayFields(),
                pending.preview().displayLabels(),
                pending.preview().affectedCount(),
                pending.expiresAt(),
                pending.confirmationToken(),
                pending.confirmationPhrase(),
                null,
                null);
    }

    public AgentRemoteActionView confirm(
            String actionId,
            String confirmationToken,
            String typedPhrase,
            KaiwuContext actor,
            RequestMetadata metadata) {
        var claimed = actions.confirm(actionId, confirmationToken, typedPhrase, actor);
        // 认领已持久化；从此不能重发。审计故障不能导致第二次执行。
        recordAudit(actor, "ACTION_CONFIRM", actionId, claimed.capabilityCode(), metadata);
        try {
            byte[] response = transport.send(request("EXECUTE", actor, claimed));
            return view(actions.acceptResult(claimed, response, actor));
        } catch (RuntimeException uncertain) {
            LOG.warn("Remote Agent execution outcome unknown: actionId={}", actionId);
            return view(actions.markUnknown(claimed, actor));
        }
    }

    public AgentRemoteActionView cancel(String actionId, KaiwuContext actor, RequestMetadata metadata) {
        var state = actions.cancel(actionId, actor);
        recordAudit(actor, "ACTION_CANCEL", actionId, state.capabilityCode(), metadata);
        return view(state);
    }

    public AgentRemoteActionView status(String actionId, KaiwuContext actor) {
        var state = actions.status(actionId, actor);
        if (!("EXECUTING".equals(state.status()) || "UNKNOWN".equals(state.status()))) return view(state);
        var claimed = actions.queryBinding(actionId, actor);
        try {
            return view(actions.acceptResult(claimed, transport.send(request("RESULT", actor, claimed)), actor));
        } catch (RuntimeException unavailable) {
            // 查账本失败或查无结果都不能推断原执行失败，也不能重新执行。
            return view(actions.status(actionId, actor));
        }
    }

    private static RemoteWriteTransport.Request request(
            String operation, KaiwuContext actor, AgentRemoteActionService.Claimed claimed) {
        return new RemoteWriteTransport.Request(
                actor.sessionId(),
                operation,
                claimed.capabilityCode(),
                claimed.version(),
                claimed.manifestHash(),
                claimed.paramsJson(),
                claimed.preconditionsJson(),
                claimed.previewHash(),
                claimed.actionId(),
                claimed.expiresAtMillis(),
                claimed.correlationId());
    }

    private static AgentRemoteActionView view(AgentRemoteActionService.State state) {
        return new AgentRemoteActionView(
                state.actionId(),
                state.projectId(),
                state.projectCode(),
                state.capabilityCode(),
                state.capabilityName(),
                state.version(),
                state.status(),
                state.confirmationMode(),
                state.preview().displayFields(),
                state.preview().displayLabels(),
                state.preview().affectedCount(),
                state.expiresAt(),
                null,
                null,
                state.reasonCode(),
                state.result());
    }

    private void recordAudit(
            KaiwuContext actor, String operation, String actionId, String code, RequestMetadata metadata) {
        try {
            audit.recordOperation(
                    actor,
                    "agent",
                    operation,
                    "/api/agent/remote-actions",
                    "actionId=" + actionId + " capability=" + code,
                    metadata);
        } catch (RuntimeException unavailable) {
            LOG.warn("Remote Agent audit unavailable: actionId={}", actionId);
        }
    }
}
