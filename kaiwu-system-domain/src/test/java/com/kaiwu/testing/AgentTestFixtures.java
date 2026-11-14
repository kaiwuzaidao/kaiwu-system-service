package com.kaiwu.testing;

import com.kaiwu.module.agent.protocol.*;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.util.*;

/** Shared test values without coupling to a test lifecycle or production authorization. */
public final class AgentTestFixtures {
    private AgentTestFixtures() {}

    public static KaiwuContext actor(String user, String session) {
        return new KaiwuContext(
                user,
                session,
                null,
                null,
                Set.of("system:agent:ask", "system:project:create"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "jti");
    }

    public static CapabilityManifest manifest(String version) {
        return new CapabilityManifest(
                "crm",
                "crm.record.search",
                version,
                "查询记录",
                "record:record:list",
                DataScope.MEMBER_PROJECTS,
                Map.of("keyword", ParamSpec.optionalString(100)),
                Set.of("id", "title"),
                Map.of(),
                true,
                true,
                ConfirmationMode.NONE,
                3000);
    }
}
