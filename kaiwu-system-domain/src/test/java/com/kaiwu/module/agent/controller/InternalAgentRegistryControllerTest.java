package com.kaiwu.module.agent.controller;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.GlobalExceptionHandler;
import com.kaiwu.module.agent.protocol.AgentManifestCodec;
import com.kaiwu.module.agent.service.AgentRegistryService;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class InternalAgentRegistryControllerTest {
    private final AgentRegistryService service = mock(AgentRegistryService.class);
    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(new InternalAgentRegistryController(service))
            .setControllerAdvice(new GlobalExceptionHandler())
            .build();

    @Test
    void limitsBodyBeforeInvokingService() throws Exception {
        mvc.perform(post("/api/internal/agent/capabilities/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(new byte[AgentManifestCodec.MAX_BYTES + 1]))
                .andExpect(status().is(413));
        verifyNoInteractions(service);
    }

    @Test
    void missingCredentialReturnsUniformUnauthorized() throws Exception {
        when(service.register(isNull(), any()))
                .thenThrow(new ApiException(HttpStatus.UNAUTHORIZED, "凭据无效", "api.common.unauthorized"));
        mvc.perform(post("/api/internal/agent/capabilities/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void heartbeatRequiresExactVersionAndHash() throws Exception {
        mvc.perform(post("/api/internal/agent/capabilities/heartbeat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"capabilityCode\":\"crm.record.search\",\"version\":\"1\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(service);
    }
}
