package com.kaiwu.module.agent.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.planning.AgentPlan;
import com.kaiwu.module.agent.vo.AgentActionView;
import com.kaiwu.starter.KaiwuContext;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface AgentActionService {

    AgentActionView preview(AgentPlan.Call call, KaiwuContext actor, RequestMetadata metadata);

    AgentActionView confirm(String id, String token, KaiwuContext actor, RequestMetadata metadata);

    AgentActionView confirm(String id, String token, String phrase, KaiwuContext actor, RequestMetadata metadata);

    AgentActionView cancel(String id, KaiwuContext actor, RequestMetadata metadata);

    AgentActionView status(String id, KaiwuContext actor);
}
