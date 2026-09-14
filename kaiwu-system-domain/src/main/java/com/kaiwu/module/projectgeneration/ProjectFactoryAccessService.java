package com.kaiwu.module.projectgeneration;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.project.ProjectRepository;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.port.ProjectGenerationProjectPort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * 项目工厂除 system 平台权限外，还要求目标项目的 ACTIVE project-admin。
 */
@Service
public class ProjectFactoryAccessService implements ProjectGenerationProjectPort {

    private final ProjectRepository projectRepository;

    public ProjectFactoryAccessService(ProjectRepository projectRepository) {
        this.projectRepository = projectRepository;
    }

    /** 校验用户是该项目的管理员；不是则 403。项目工厂的所有写操作都先过这一关。 */
    @Override
    public ProjectView requireProjectAdmin(String projectId, String userId) {
        ProjectView project = projectRepository
                .findProject(projectId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目不存在", "api.project.notFound"));
        if (project.builtIn()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST, "内置 system 项目已有真实源码，不能通过项目工厂生成", "api.projectFactory.builtInForbidden");
        }
        if (!"ACTIVE".equals(project.status())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "只有启用项目可以生成", "api.projectFactory.activeRequired");
        }
        if (!projectRepository.activeMemberExists(projectId, userId)
                || !projectRepository.findCurrentRoleCodes(projectId, userId).contains("project-admin")) {
            throw new ApiException(HttpStatus.FORBIDDEN, "只有目标项目的有效项目管理员可以使用项目工厂", "api.projectFactory.adminRequired");
        }
        return project;
    }

    @Override
    public String upsertGeneratedMenu(
            String id,
            String projectId,
            String parentId,
            String name,
            String type,
            String path,
            String component,
            String permission,
            int sortNo) {
        return projectRepository.upsertGeneratedMenu(
                id, projectId, parentId, name, type, path, component, permission, sortNo);
    }

    @Override
    public void grantMenuToAdmin(String projectId, String menuId) {
        projectRepository.grantMenuToAdmin(projectId, menuId);
    }
}
