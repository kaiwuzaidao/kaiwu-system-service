package com.kaiwu.module.project.repository;

import com.kaiwu.module.project.entity.BackendServiceRow;
import com.kaiwu.module.project.mapper.ProjectBackendServiceMapper;
import com.kaiwu.module.project.mapper.ProjectMapper;
import com.kaiwu.module.project.vo.BackendServiceView;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Repository;

/** 项目服务登记持久化，调用方负责事务和项目锁。 */
@Repository
public class ProjectBackendServiceRepository {
    private final ProjectBackendServiceMapper mapper;
    private final ProjectMapper projects;
    /** 注入登记与项目锁 Mapper。 */
    public ProjectBackendServiceRepository(ProjectBackendServiceMapper mapper, ProjectMapper projects) {
        this.mapper = mapper;
        this.projects = projects;
    }
    /** 锁住项目行，串行旧地址更新与登记变更。 */
    public boolean lockProject(String projectId) {
        return projects.findProjectForUpdate(projectId) != null;
    }
    /** 返回项目登记，不泄漏其他项目。 */
    public List<BackendServiceView> list(String projectId) {
        return mapper.list(projectId).stream().map(this::view).toList();
    }
    /** 获取单条登记。 */
    public Optional<BackendServiceView> find(String projectId, String serviceCode) {
        return Optional.ofNullable(mapper.find(projectId, serviceCode)).map(this::view);
    }
    /** 写入新服务。 */
    public void insert(String projectId, String serviceCode, String url) {
        mapper.insert(projectId, serviceCode, url);
    }
    /** 更新服务地址，default 同步旧项目字段。 */
    public void updateUrl(String projectId, String serviceCode, String url) {
        if ("default".equals(serviceCode)) mapper.updateLegacyUrl(projectId, url);
        mapper.updateUrl(projectId, serviceCode, url);
    }
    /** 更改可发布状态。 */
    public void updateStatus(String projectId, String serviceCode, String status) {
        mapper.updateStatus(projectId, serviceCode, status);
    }

    /** 只导出登记编码、地址和状态，持久化行不直接作为HTTP输出。 */
    private BackendServiceView view(BackendServiceRow row) {
        return new BackendServiceView(row.getServiceCode(), row.getServiceUrl(), row.getStatus());
    }
}
