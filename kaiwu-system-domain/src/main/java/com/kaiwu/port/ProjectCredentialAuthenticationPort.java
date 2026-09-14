package com.kaiwu.port;

/** 项目服务凭据认证边界。 */
public interface ProjectCredentialAuthenticationPort {

    AuthenticatedProject authenticate(String token);

    record AuthenticatedProject(String credentialId, String projectId) {}
}
