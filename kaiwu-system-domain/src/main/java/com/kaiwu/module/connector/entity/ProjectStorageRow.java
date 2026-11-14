package com.kaiwu.module.connector.entity;

import java.time.LocalDateTime;

/**
 * {@code sys_project_storage} 关联项目与账号后的查询投影。列顺序必须与 {@code ProjectStorageMapper}
 * 的 SELECT 一致。
 *
 * @param id 绑定 ID
 * @param projectId 项目 ID
 * @param projectCode 项目编码
 * @param projectName 项目名称
 * @param storageName 项目内存储名
 * @param accountId 存储账号 ID
 * @param accountName 存储账号名称
 * @param bucket 账号的桶名
 * @param status 绑定状态
 * @param maxObjectBytes 单个对象字节上限
 * @param allowedContentTypes 逗号分隔的 MIME 类型，可空
 * @param createdAt 创建时间
 */
public record ProjectStorageRow(
        String id,
        String projectId,
        String projectCode,
        String projectName,
        String storageName,
        String accountId,
        String accountName,
        String bucket,
        String status,
        long maxObjectBytes,
        String allowedContentTypes,
        LocalDateTime createdAt) {}
