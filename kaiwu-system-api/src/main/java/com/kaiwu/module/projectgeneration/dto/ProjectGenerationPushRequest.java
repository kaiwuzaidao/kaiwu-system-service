package com.kaiwu.module.projectgeneration.dto;

import jakarta.validation.constraints.Size;

/**
 * 一次性 GitLab 初始推送参数。
 *
 * <p>填写两个仓库 URL 时绑定已有空仓库；不填写时使用请求或平台默认 Group 创建。</p>
 */
public record ProjectGenerationPushRequest(
        @Size(max = 128, message = "GitLab Group 不能超过 128 个字符") String groupId,
        @Size(max = 512, message = "后端仓库地址不能超过 512 个字符") String backendRepositoryUrl,
        @Size(max = 512, message = "前端仓库地址不能超过 512 个字符") String frontendRepositoryUrl) {}
