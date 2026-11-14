package com.kaiwu.module.project.adapter;

import com.kaiwu.module.project.mapper.ProjectMapper;
import com.kaiwu.module.project.service.ProjectDataScopeService;
import com.kaiwu.module.project.vo.ProjectAccessView;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;

/**
 * 业务项目入口授权：某个用户能不能进某个项目，以及带着哪些项目事实进去（ADR 0003、ADR 0004）。
 *
 * <p>只服务 Gateway 一个调用方，且**只读**。System 是权限唯一事实源，
 * 这里是那份事实唯一对外的入口形态——Gateway 不查库、不缓存权限表结构，
 * 只拿这份已经算好的快照。</p>
 *
 * <p>三跳缺一不可：项目必须 ACTIVE、成员必须 ACTIVE、权限来自项目内启用的角色与菜单。
 * 任何一跳不满足就返回空，Gateway 据此拒绝入口——不返回「空权限的通行证」，
 * 那会让越权表现为「进得去但什么都点不了」，掩盖真正的成员关系问题。</p>
 */
@Service
public class GatewayProjectAccessService implements com.kaiwu.port.ProjectAgentAccessPort {

    private final ProjectMapper mapper;
    private final ProjectDataScopeService dataScopeService;

    /** 注入项目 Mapper 与数据范围服务（ADR 0044）。 */
    public GatewayProjectAccessService(ProjectMapper mapper, ProjectDataScopeService dataScopeService) {
        this.mapper = mapper;
        this.dataScopeService = dataScopeService;
    }

    /**
     * 解析用户在指定项目下的入口授权。
     *
     * @param projectCode Route 绑定的稳定项目编码，不接受客户端提交的项目 ID
     * @param userId      已由 Gateway 验证过的用户 ID
     * @return 有权进入时返回快照；项目不可用或不是 ACTIVE 成员时返回 {@link Optional#empty()}
     */
    public Optional<ProjectAccessView> resolve(String projectCode, String userId) {
        String projectId = mapper.findActiveProjectIdByCode(projectCode);
        if (projectId == null) {
            return Optional.empty();
        }
        if (mapper.countActiveMember(projectId, userId) == 0) {
            return Optional.empty();
        }
        List<String> permissions = mapper.findCurrentPermissions(projectId, userId);
        List<String> roleCodes = mapper.findMemberRoleCodes(projectId, userId);
        // 数据范围只在已确认是有效成员之后才解析；项目没有受控资源时为空，响应与此前一致。
        return Optional.of(new ProjectAccessView(
                projectId,
                projectCode,
                permissions,
                roleCodes,
                dataScopeService.snapshot(projectId, userId).orElse(null)));
    }
}
