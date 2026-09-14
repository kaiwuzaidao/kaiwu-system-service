package com.kaiwu.module.auth.vo;

/**
 * 登录或刷新结果。
 */
public record TokenView(String accessToken, long expiresIn, CurrentUserView user) {}
