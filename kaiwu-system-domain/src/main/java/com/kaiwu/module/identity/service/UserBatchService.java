package com.kaiwu.module.identity.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.user.vo.UserImportResult;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface UserBatchService {

    byte[] template();

    byte[] template(String language);

    byte[] exportUsers(String keyword, KaiwuContext actor, RequestMetadata metadata);

    byte[] exportUsers(String keyword, KaiwuContext actor, RequestMetadata metadata, String language);

    UserImportResult importUsers(byte[] bytes, KaiwuContext actor, RequestMetadata metadata);

    void updateStatuses(List<String> userIds, String status, KaiwuContext actor, RequestMetadata metadata);
}
