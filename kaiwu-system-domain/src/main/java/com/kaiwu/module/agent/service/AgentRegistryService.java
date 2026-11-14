package com.kaiwu.module.agent.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.dto.AgentCapabilityBatchReviewRequest;
import com.kaiwu.module.agent.dto.AgentCapabilityReviewRequest;
import com.kaiwu.module.agent.dto.AgentCapabilityRevision;
import com.kaiwu.module.agent.entity.*;
import com.kaiwu.module.agent.vo.AgentCredentialView;
import com.kaiwu.module.agent.vo.AgentRegistrationView;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface AgentRegistryService {

    AgentCredentialView rotateCredential(String projectId, KaiwuContext actor, RequestMetadata metadata);

    void revokeCredential(String projectId, KaiwuContext actor, RequestMetadata metadata);

    AgentRegistrationView register(String authorization, byte[] body);

    AgentRegistrationView heartbeat(String authorization, AgentCapabilityRevision revision);

    List<AgentRegistrationView> list(String projectId, KaiwuContext actor);

    com.kaiwu.module.agent.vo.AgentCapabilityDetailView detail(String projectId, String code, KaiwuContext actor);

    AgentRegistrationView review(
            String projectId, AgentCapabilityReviewRequest request, KaiwuContext actor, RequestMetadata metadata);

    List<AgentRegistrationView> reviewBatch(
            String projectId, AgentCapabilityBatchReviewRequest request, KaiwuContext actor, RequestMetadata metadata);
}
