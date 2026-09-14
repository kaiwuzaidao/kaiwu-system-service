package com.kaiwu.module.gitlab.vo;

import java.time.LocalDateTime;

/**
 * GitLab 连接测试结果。
 */
public record GitlabConnectionTestView(boolean success, String message, LocalDateTime testedAt) {}
