package com.kaiwu.module.connector.dto.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;

/**
 * 把项目的某个存储名绑定到存储账号。已有生效绑定且账号不同时，旧绑定转为只读。
 *
 * @param projectId 业务项目 ID
 * @param storageName 项目内的存储名，默认 {@code default}
 * @param accountId 存储账号 ID
 * @param maxObjectBytes 单个对象字节上限，由业务项目 starter 执行
 * @param allowedContentTypes 允许的 MIME 类型；为空表示不限制
 */
public record ProjectStorageBindRequest(
        @NotBlank(message = "项目不能为空") String projectId,
        @Pattern(regexp = "[a-z0-9][a-z0-9_-]{0,31}", message = "存储名只允许小写字母、数字、下划线和连字符") String storageName,
        @NotBlank(message = "存储账号不能为空") String accountId,
        @Min(value = 1, message = "大小上限必须大于 0") @Max(value = 5368709120L, message = "大小上限不能超过 5GB") Long maxObjectBytes,
        @Size(max = 20, message = "最多配置 20 个 MIME 类型") List<@Size(max = 127) String> allowedContentTypes) {}
