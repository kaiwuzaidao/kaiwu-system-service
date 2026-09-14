package com.kaiwu.port;

import java.util.Optional;

/** 项目服务凭据认证读取持久化事实的边界。 */
public interface ProjectCredentialStorePort {

    Optional<StoredCredential> findActive(String credentialId);

    record StoredCredential(String id, String projectId, String tokenHash) {}
}
