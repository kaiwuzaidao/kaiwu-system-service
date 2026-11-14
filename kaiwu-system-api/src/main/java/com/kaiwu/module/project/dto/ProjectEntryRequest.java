package com.kaiwu.module.project.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** CLI 登记项目入口，浏览器路径由服务端按已登记项目编码生成。 */
public record ProjectEntryRequest(
        @NotBlank @Size(max = 100) String backendLabel,
        @NotBlank @Size(max = 512) @Pattern(regexp = "(?:https?|lb)://[a-zA-Z0-9][a-zA-Z0-9.-]*(?::[0-9]{1,5})?")
                String serviceUrl) {}
