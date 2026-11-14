package com.kaiwu.module.operation.service;

import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.audit.vo.LoginLogView;
import com.kaiwu.module.audit.vo.OnlineSessionView;
import com.kaiwu.module.audit.vo.OperationLogView;
import com.kaiwu.starter.KaiwuContext;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface LogCenterService {

    PageResult<OperationLogView> operations(String username, String module, long current, long size);

    PageResult<LoginLogView> logins(String username, String status, long current, long size);

    PageResult<OnlineSessionView> sessions(String username, String status, long current, long size);

    void forceOffline(String sessionId, String reason, KaiwuContext actor, RequestMetadata metadata);
}
