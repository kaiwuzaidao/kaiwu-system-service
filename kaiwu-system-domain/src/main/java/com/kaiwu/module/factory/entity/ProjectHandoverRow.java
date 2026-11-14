package com.kaiwu.module.factory.entity;

import java.time.LocalDateTime;

/**
 * {@code sys_project_config_handover} 的查询投影（ADR 0042）。列顺序必须与 {@code ProjectHandoverMapper}
 * 的 SELECT 一致：MyBatis 按列顺序调用 record 的规范构造器。
 *
 * @param id 记录 ID
 * @param projectId 项目 ID
 * @param status SUCCESS / FAILED
 * @param packageDigest 移交包摘要，命令行同步清单时为空
 * @param sourceHost 来源主机，仅供人核对
 * @param sourceExportedBy 导出人用户 ID
 * @param sourceExportedAt 导出时间原文
 * @param planHash 执行时的计划摘要
 * @param gitCommit 清单所在提交，可空
 * @param appliedAccess 是否勾选了导入授权
 * @param changeCount 实际执行的新增与更新条数
 * @param deleteCount 实际执行的删除条数
 * @param failureReason 失败原因，成功时为空
 * @param operatorId 执行人用户 ID
 * @param createdAt 执行时间
 */
public record ProjectHandoverRow(
        String id,
        String projectId,
        String status,
        String packageDigest,
        String sourceHost,
        String sourceExportedBy,
        String sourceExportedAt,
        String planHash,
        String gitCommit,
        boolean appliedAccess,
        int changeCount,
        int deleteCount,
        String failureReason,
        String operatorId,
        LocalDateTime createdAt) {}
