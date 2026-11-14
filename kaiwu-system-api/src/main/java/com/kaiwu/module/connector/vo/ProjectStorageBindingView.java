package com.kaiwu.module.connector.vo;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 项目存储绑定的管理视图。
 *
 * @param id 绑定 ID，也是业务记录里的 {@code storage_ref}
 * @param projectId 项目 ID
 * @param projectCode 项目编码，也是对象 key 前缀
 * @param projectName 项目名称
 * @param storageName 项目内存储名
 * @param accountId 存储账号 ID
 * @param accountName 存储账号名称
 * @param bucket 桶名
 * @param status 绑定状态
 * @param maxObjectBytes 单个对象字节上限
 * @param allowedContentTypes 允许的 MIME 类型，空表示不限制
 * @param createdAt 创建时间
 */
public record ProjectStorageBindingView(
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
        List<String> allowedContentTypes,
        LocalDateTime createdAt) {}
