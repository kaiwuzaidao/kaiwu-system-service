package com.kaiwu.module.projecthealth.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

/**
 * 项目体检报告实体。
 *
 * <p>主键就是 {@code project_id}——每个项目只保留最近一次结论（ADR 0012 第 2 节），
 * 不是历史表。</p>
 */
@TableName("sys_project_health_report")
public class ProjectHealthReportEntity {

    /** 项目 ID，同时是主键 */
    @TableId(value = "project_id", type = IdType.INPUT)
    private Long projectId;

    /** 结论 */
    private String verdict;

    /** 逐项检查结果 JSON */
    private String checksJson;

    /** 本次体检时间 */
    private LocalDateTime checkedAt;

    /** 创建时间 */
    private LocalDateTime createdAt;

    /** 更新时间 */
    private LocalDateTime updatedAt;

    public Long getProjectId() {
        return projectId;
    }

    public void setProjectId(Long projectId) {
        this.projectId = projectId;
    }

    public String getVerdict() {
        return verdict;
    }

    public void setVerdict(String verdict) {
        this.verdict = verdict;
    }

    public String getChecksJson() {
        return checksJson;
    }

    public void setChecksJson(String checksJson) {
        this.checksJson = checksJson;
    }

    public LocalDateTime getCheckedAt() {
        return checkedAt;
    }

    public void setCheckedAt(LocalDateTime checkedAt) {
        this.checkedAt = checkedAt;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}
