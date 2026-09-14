package com.kaiwu.module.project.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record ProjectUpdateRequest(
        @NotBlank(message = "项目名称不能为空") @Size(max = 100, message = "项目名称不能超过 100 个字符") String projectName,
        @Size(max = 500, message = "项目描述不能超过 500 个字符") String description,
        @NotBlank(message = "基础包名不能为空")
                @Pattern(regexp = "^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$", message = "基础包名格式不正确")
                @Size(max = 128, message = "基础包名不能超过 128 个字符")
                String packageName,
        @Size(max = 512, message = "仓库地址不能超过 512 个字符") String repositoryUrl,
        @Size(max = 256, message = "GitLab 项目标识不能超过 256 个字符") String gitlabProjectId,
        @NotBlank(message = "默认分支不能为空") @Pattern(regexp = "[A-Za-z0-9._/-]{1,64}", message = "默认分支格式不正确")
                String defaultBranch,
        @Size(max = 512, message = "后台入口不能超过 512 个字符") String backendUrl,
        @Size(max = 100, message = "后台入口名称不能超过 100 个字符") String backendLabel,
        /**
         * Gateway PROJECT 路由的上游地址。
         *
         * <p>只允许 http/https/lb 三种 scheme：这个值会成为 Gateway 的转发目标，
         * 放开 scheme 等于允许把网关指向任意协议的内网端点。</p>
         */
        @Pattern(
                        regexp = "^$|^(https?|lb)://[A-Za-z0-9._~:/?#\\[\\]@!$&'()*+,;=%-]{1,505}$",
                        message = "服务地址必须以 http://、https:// 或 lb:// 开头")
                @Size(max = 512, message = "服务地址不能超过 512 个字符")
                String serviceUrl) {}
