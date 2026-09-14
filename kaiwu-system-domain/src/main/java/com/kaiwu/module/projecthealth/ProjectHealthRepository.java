package com.kaiwu.module.projecthealth;

import com.kaiwu.module.projecthealth.entity.ProjectHealthReportEntity;
import com.kaiwu.module.projecthealth.mapper.ProjectHealthReportMapper;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Optional;
import org.springframework.stereotype.Repository;

/** 体检报告持久化。每个项目只保留最近一次结论（ADR 0012 第 2 节）。 */
@Repository
public class ProjectHealthRepository {

    private final ProjectHealthReportMapper mapper;

    private final Clock clock;

    public ProjectHealthRepository(ProjectHealthReportMapper mapper, Clock clock) {
        this.mapper = mapper;
        this.clock = clock;
    }

    public boolean healthCheckEnabled(String projectId) {
        return Boolean.TRUE.equals(mapper.healthCheckEnabled(Long.parseLong(projectId)));
    }

    public void setHealthCheckEnabled(String projectId, boolean enabled) {
        mapper.setHealthCheckEnabled(Long.parseLong(projectId), enabled, LocalDateTime.now(clock));
    }

    public void save(String projectId, String verdict, String checksJson, LocalDateTime checkedAt) {
        mapper.upsert(Long.parseLong(projectId), verdict, checksJson, checkedAt);
    }

    /** 该项目最近一次体检结论；每个项目只保留一份，不是历史表（ADR 0012 第 2 节）。 */
    public Optional<Report> latest(String projectId) {
        ProjectHealthReportEntity entity = mapper.selectById(Long.parseLong(projectId));
        return entity == null
                ? Optional.empty()
                : Optional.of(new Report(entity.getVerdict(), entity.getChecksJson(), entity.getCheckedAt()));
    }

    public record Report(String verdict, String checksJson, LocalDateTime checkedAt) {}
}
