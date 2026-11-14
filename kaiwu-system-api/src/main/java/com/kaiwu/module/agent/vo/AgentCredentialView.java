package com.kaiwu.module.agent.vo;
/** 新凭据仅在签发时返回一次，调用方需保存在服务端 Secret 中。 */
public record AgentCredentialView(String projectId, String credentialId, String token) {
    @Override
    public String toString() {
        return "AgentCredentialView[credentialId=" + credentialId + ", token=[REDACTED]]";
    }
}
