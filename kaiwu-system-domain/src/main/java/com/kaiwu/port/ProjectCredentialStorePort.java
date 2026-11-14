package com.kaiwu.port;

import java.util.Optional;
import java.util.Set;

/** 项目服务凭据认证读取持久化事实的边界。 */
public interface ProjectCredentialStorePort {

    /** 仅返回项目与凭据均有效且未到期的认证事实，不对外暴露持久化行。 */
    Optional<StoredCredential> findActive(String credentialId);

    /** 成功认证后限频记录使用时间，失败不得影响认证。 */
    void touchLastUsed(String credentialId);

    /** 仅认证层可读取的凭据哈希、服务与范围，不能作为HTTP响应序列化。 */
    record StoredCredential(String id, String projectId, String tokenHash, String serviceCode, Set<String> scopes) {
        /** 固定持久化范围，避免认证期间被调用方修改。 */
        public StoredCredential {
            scopes = Set.copyOf(scopes);
        }
        /** 调试输出不能包含认证哈希，明文不属于此存储契约。 */
        @Override
        public String toString() {
            return "CredentialFact[id=" + id + ",projectId=" + projectId + ",serviceCode=" + serviceCode + "]";
        }
    }
}
