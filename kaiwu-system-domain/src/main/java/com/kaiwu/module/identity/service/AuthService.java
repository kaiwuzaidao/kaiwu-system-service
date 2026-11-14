package com.kaiwu.module.identity.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.auth.dto.ChangePasswordRequest;
import com.kaiwu.module.auth.dto.UpdateLocaleRequest;
import com.kaiwu.module.auth.vo.CurrentUserView;
import com.kaiwu.module.auth.vo.NavigationMenuView;
import com.kaiwu.module.auth.vo.TokenView;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.util.List;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface AuthService {

    AuthSession login(String username, String password, RequestMetadata metadata);

    AuthSession refresh(String refreshToken);

    /**
     * 为已在确认页允许设备授权的用户签发 CLI 会话（ADR 0035）。
     *
     * <p>签发的是普通在线会话，权限与用户本人相同；只额外记录来源与客户端名称供展示和审计。</p>
     */
    AuthSession openDeviceSession(String userId, String clientName, RequestMetadata metadata);

    void logout(KaiwuContext context, RequestMetadata metadata);

    void changePassword(KaiwuContext context, ChangePasswordRequest request, RequestMetadata metadata);

    CurrentUserView currentUser(KaiwuContext context);

    CurrentUserView updateLocale(KaiwuContext context, UpdateLocaleRequest request);

    CurrentUserView updateAgentAutoOpen(KaiwuContext context, boolean agentAutoOpen);

    List<NavigationMenuView> navigationMenus(KaiwuContext context);

    public record AuthSession(TokenView token, String refreshToken, Instant absoluteExpiresAt) {}
}
