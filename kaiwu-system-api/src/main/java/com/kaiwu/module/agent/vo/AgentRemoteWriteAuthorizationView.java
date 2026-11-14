package com.kaiwu.module.agent.vo;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.kaiwu.module.project.vo.DataScopeView;
import java.util.List;

/** Gateway 签发固定写用途 Context 的权威事实；不返回浏览器或模型。 */
public record AgentRemoteWriteAuthorizationView(
        String userId,
        String projectId,
        String projectCode,
        String operation,
        String code,
        String version,
        String manifestHash,
        String paramsHash,
        String preconditionsHash,
        String previewHash,
        String actionId,
        Long actionExpiresAt,
        String correlationId,
        boolean confirmed,
        int timeoutMs,
        List<String> permissions,
        List<String> projectRoleCodes,
        @JsonInclude(JsonInclude.Include.NON_NULL) DataScopeView dataScope) {}
