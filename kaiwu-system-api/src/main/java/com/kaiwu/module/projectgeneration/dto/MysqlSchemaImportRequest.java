package com.kaiwu.module.projectgeneration.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 一次性 MySQL 表结构读取请求。密码只允许在本次请求内存中使用。
 */
public record MysqlSchemaImportRequest(
        @NotBlank(message = "项目不能为空") String projectId,
        @NotBlank(message = "数据库主机不能为空") @Size(max = 253, message = "数据库主机不能超过 253 个字符") String host,
        @Min(value = 1, message = "端口必须大于 0") @Max(value = 65535, message = "端口不能超过 65535") Integer port,
        @NotBlank(message = "数据库名不能为空")
                @Pattern(regexp = "^[A-Za-z0-9_$-]{1,64}$", message = "数据库名只能包含字母、数字、下划线、$ 或中划线")
                String database,
        @NotBlank(message = "数据库用户名不能为空") @Size(max = 128, message = "数据库用户名不能超过 128 个字符") String username,
        @NotBlank(message = "数据库密码不能为空") @Size(max = 512, message = "数据库密码不能超过 512 个字符") String password) {}
