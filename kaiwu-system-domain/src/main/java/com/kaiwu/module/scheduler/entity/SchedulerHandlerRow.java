package com.kaiwu.module.scheduler.entity;

import java.time.LocalDateTime;

/** 业务侧注册的任务处理器心跳行。 */
public class SchedulerHandlerRow {

    private String projectId;
    private String taskType;
    private String taskName;
    private LocalDateTime lastSeenAt;

    public String getProjectId() {
        return projectId;
    }

    public void setProjectId(String projectId) {
        this.projectId = projectId;
    }

    public String getTaskType() {
        return taskType;
    }

    public void setTaskType(String taskType) {
        this.taskType = taskType;
    }

    public String getTaskName() {
        return taskName;
    }

    public void setTaskName(String taskName) {
        this.taskName = taskName;
    }

    public LocalDateTime getLastSeenAt() {
        return lastSeenAt;
    }

    public void setLastSeenAt(LocalDateTime lastSeenAt) {
        this.lastSeenAt = lastSeenAt;
    }
}
