package com.kaiwu.module.agent.repository;

import com.kaiwu.module.agent.entity.AgentRemoteActionEntity;
import com.kaiwu.module.agent.mapper.AgentRemoteActionMapper;
import java.time.LocalDateTime;
import java.util.Optional;
import org.springframework.stereotype.Repository;

/** 远程写任务持久化状态；只提供窄状态迁移，不能从 UNKNOWN 重发执行。 */
@Repository
public class AgentRemoteActionRepository {
    private final AgentRemoteActionMapper mapper;

    public AgentRemoteActionRepository(AgentRemoteActionMapper mapper) {
        this.mapper = mapper;
    }

    public void create(AgentRemoteActionEntity action) {
        if (action == null
                || !"PENDING".equals(action.getStatus())
                || !("REQUIRED".equals(action.getConfirmationMode()) || "STRONG".equals(action.getConfirmationMode()))
                || action.getFrozenCiphertext() == null
                || !action.getFrozenCiphertext().startsWith("v1:")
                || action.getTokenHash() == null
                || !action.getTokenHash().matches("[0-9a-f]{64}"))
            throw new IllegalArgumentException("Invalid remote Agent action");
        mapper.insert(action);
    }

    public Optional<AgentRemoteActionEntity> owned(String actionId, String userId, String sessionId) {
        AgentRemoteActionEntity action = mapper.selectById(actionId);
        if (action == null || !userId.equals(action.getUserId()) || !sessionId.equals(action.getSessionId()))
            return Optional.empty();
        return Optional.of(action);
    }

    public boolean claim(AgentRemoteActionEntity action, LocalDateTime now) {
        return mapper.claim(action.getActionId(), action.getUserId(), action.getSessionId(), action.getRevision(), now)
                == 1;
    }

    public boolean closePending(AgentRemoteActionEntity action, String target, String reason, LocalDateTime now) {
        if (!("CANCELLED".equals(target) || "EXPIRED".equals(target) || "REJECTED".equals(target)))
            throw new IllegalArgumentException("Invalid remote Agent transition");
        return mapper.closePending(
                        action.getActionId(),
                        action.getUserId(),
                        action.getSessionId(),
                        action.getRevision(),
                        target,
                        reason,
                        now)
                == 1;
    }

    public boolean complete(
            AgentRemoteActionEntity action, String target, String resultCiphertext, String reason, LocalDateTime now) {
        terminal(target, resultCiphertext);
        return mapper.complete(
                        action.getActionId(),
                        action.getUserId(),
                        action.getSessionId(),
                        action.getRevision(),
                        target,
                        resultCiphertext,
                        reason,
                        now)
                == 1;
    }

    public boolean markUnknown(AgentRemoteActionEntity action, LocalDateTime cutoff, LocalDateTime now) {
        return mapper.markUnknown(
                        action.getActionId(),
                        action.getUserId(),
                        action.getSessionId(),
                        action.getRevision(),
                        cutoff,
                        now)
                == 1;
    }

    public boolean reconcile(
            AgentRemoteActionEntity action, String target, String resultCiphertext, String reason, LocalDateTime now) {
        terminal(target, resultCiphertext);
        return mapper.reconcile(
                        action.getActionId(),
                        action.getUserId(),
                        action.getSessionId(),
                        action.getRevision(),
                        target,
                        resultCiphertext,
                        reason,
                        now)
                == 1;
    }

    private static void terminal(String target, String resultCiphertext) {
        if (!("SUCCEEDED".equals(target) || "FAILED".equals(target))
                || ("SUCCEEDED".equals(target) && (resultCiphertext == null || !resultCiphertext.startsWith("v1:"))))
            throw new IllegalArgumentException("Invalid remote Agent result");
    }
}
