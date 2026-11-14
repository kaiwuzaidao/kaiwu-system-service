package com.kaiwu.module.agent.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.dto.AgentConversationTurn;
import com.kaiwu.module.agent.vo.AgentAnswerView;
import com.kaiwu.module.agent.vo.AgentLocalCapabilityView;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface AgentService {

    AgentAnswerView ask(String question, KaiwuContext actor, RequestMetadata metadata);

    List<AgentLocalCapabilityView> localCapabilities(KaiwuContext actor);

    AgentAnswerView ask(
            String question, List<AgentConversationTurn> history, KaiwuContext actor, RequestMetadata metadata);

    AgentAnswerView ask(
            String question,
            List<AgentConversationTurn> history,
            com.kaiwu.module.agent.dto.AgentInputSubmission input,
            KaiwuContext actor,
            RequestMetadata metadata);

    AgentAnswerView ask(
            String question,
            List<AgentConversationTurn> history,
            com.kaiwu.module.agent.dto.AgentInputSubmission input,
            List<String> preferences,
            KaiwuContext actor,
            RequestMetadata metadata);
}
