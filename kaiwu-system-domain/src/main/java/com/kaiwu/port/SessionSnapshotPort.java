package com.kaiwu.port;

import java.time.Instant;
import java.util.Set;

/** 已认证会话在缓存中的权限快照边界。 */
public interface SessionSnapshotPort {

    void write(String sessionId, String userId, String username, Set<String> permissions, Instant expiresAt);

    void delete(String sessionId);

    /** 迁移切换时清除全部旧权限快照。 */
    void deleteAll();
}
