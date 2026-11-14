package com.kaiwu.module.factory.vo;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 项目配置移交记录（ADR 0042）。
 *
 * @param id               记录 ID
 * @param status           SUCCESS / FAILED
 * @param packageDigest    移交包摘要，命令行同步清单时为空
 * @param sourceHost       来源主机，仅供人核对
 * @param sourceExportedBy 导出人用户 ID
 * @param sourceExportedAt 导出时间原文
 * @param operatorId       执行人用户 ID
 * @param appliedAccess    是否勾选了导入授权
 * @param changeCount      实际执行的新增与更新条数
 * @param deleteCount      实际执行的删除条数
 * @param failureReason    失败原因，成功时为空
 * @param createdAt        执行时间
 * @param changes          本次计划的全部条目，仅详情接口返回，列表为空
 */
public record ProjectHandoverView(
        String id,
        String status,
        String packageDigest,
        String sourceHost,
        String sourceExportedBy,
        String sourceExportedAt,
        String operatorId,
        boolean appliedAccess,
        int changeCount,
        int deleteCount,
        String failureReason,
        LocalDateTime createdAt,
        List<ProjectManifestPlanView.Change> changes) {}
