package com.kaiwu.module.auth.vo;

import java.util.Set;

/**
 * 当前平台用户的最小身份快照。
 */
public record CurrentUserView(
        String id,
        String username,
        String displayName,
        Set<String> permissions,
        /** System 持久化的界面语言偏好。 */
        String locale,
        /** 为 true 时前端必须先引导用户修改密码，再放行其它页面。 */
        boolean mustChangePassword,
        /** System 持久化的「登录后默认进入 AI 助手」偏好；只影响界面入口，不授予任何权限。 */
        boolean agentAutoOpen) {}
