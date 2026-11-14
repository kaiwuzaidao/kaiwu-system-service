package com.kaiwu.module.agent.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.dto.AgentMessageRequest;
import com.kaiwu.module.agent.vo.*;
import com.kaiwu.starter.KaiwuContext;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface AgentConversationService {

    AgentMessageResult ask(String id, AgentMessageRequest request, KaiwuContext actor, RequestMetadata metadata);
}
