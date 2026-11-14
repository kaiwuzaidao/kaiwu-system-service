package com.kaiwu.module.configuration.adapter;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.project.repository.ProjectRepository;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.port.ProjectI18nAccessPort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * 项目级国际化的权限判定（ADR 0037）：目标项目的 ACTIVE project-admin 即可，
 * 不要求平台级国际化权限。内置 system 项目的文案属于平台资源，不走这里。
 */
@Service
public class ProjectI18nAccessAdapter implements ProjectI18nAccessPort {

    private final ProjectRepository projectRepository;

    public ProjectI18nAccessAdapter(ProjectRepository projectRepository) {
        this.projectRepository = projectRepository;
    }

    @Override
    public void requireProjectAdmin(String projectId, String userId) {
        ProjectView project = projectRepository
                .findProject(projectId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目不存在", "api.project.notFound"));
        if (project.builtIn()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "内置项目的文案属于平台资源", "api.i18n.builtInProjectForbidden");
        }
        if (!"ACTIVE".equals(project.status())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目未启用", "api.i18n.projectInactive");
        }
        if (!projectRepository.activeMemberExists(projectId, userId)
                || !projectRepository.findCurrentRoleCodes(projectId, userId).contains("project-admin")) {
            throw new ApiException(HttpStatus.FORBIDDEN, "只有目标项目的有效项目管理员可以维护项目文案", "api.i18n.projectAdminRequired");
        }
    }
}
