package com.kaiwu.module.gitlab.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 受管 GitLab 配置。Token 留空表示保留原值。
 */
public record GitlabConfigSaveRequest(
        @NotBlank(message = "GitLab 地址不能为空") @Size(max = 512, message = "GitLab 地址不能超过 512 个字符") String baseUrl,
        @Size(max = 128, message = "默认 Group 不能超过 128 个字符") String defaultGroupId,
        @Size(max = 4096, message = "Token 不能超过 4096 个字符") String token,
        Boolean clearToken,
        Boolean enabled) {}
