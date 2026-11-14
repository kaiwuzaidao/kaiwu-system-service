package com.kaiwu.module.agent.dto;

import jakarta.validation.constraints.NotNull;

/**
 * 当前用户的助手界面偏好。
 *
 * @param autoOpen 登录后是否默认进入 AI 助手聊天模式；只影响界面入口，不授予任何权限
 */
public record AgentPreferenceRequest(@NotNull(message = "偏好值不能为空") Boolean autoOpen) {}
