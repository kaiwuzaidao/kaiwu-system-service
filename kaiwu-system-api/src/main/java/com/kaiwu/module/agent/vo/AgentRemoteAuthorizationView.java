package com.kaiwu.module.agent.vo;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.kaiwu.module.project.vo.DataScopeView;
import java.util.List;

/** 仅供 Gateway 签发专用 Context，不返回浏览器或模型。 */
public record AgentRemoteAuthorizationView(
        String userId,
        String projectId,
        String projectCode,
        String code,
        String version,
        String manifestHash,
        int timeoutMs,
        List<String> permissions,
        List<String> projectRoleCodes,
        @JsonInclude(JsonInclude.Include.NON_NULL) DataScopeView dataScope) {}
