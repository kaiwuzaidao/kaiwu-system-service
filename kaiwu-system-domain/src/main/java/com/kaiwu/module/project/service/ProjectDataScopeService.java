package com.kaiwu.module.project.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.dto.ProjectRoleDataScopeRequest;
import com.kaiwu.module.project.vo.DataScopeView;
import com.kaiwu.module.project.vo.ProjectDataResourceView;
import com.kaiwu.module.project.vo.ProjectRoleDataScopeView;
import com.kaiwu.starter.KaiwuContext;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 项目数据范围用例（ADR 0044）：给 Gateway 的快照解析，以及管理员按角色查看、保存范围。
 */
public interface ProjectDataScopeService {

    /**
     * 解析用户在项目内的数据范围快照。
     *
     * @return 项目没有任何已启用的受控资源时为空，此时项目权限快照与引入数据范围之前完全一致
     * @throws com.kaiwu.common.ApiException 规范化后超过体积上限时抛 403，不截断
     */
    Optional<DataScopeView> snapshot(String projectId, String userId);

    /** 查看角色在项目各已启用资源上的数据范围；内置 {@code project-admin} 只读且固定为全部。 */
    ProjectRoleDataScopeView roleScopes(String projectId, String roleId);

    /**
     * 整体替换角色的数据范围配置（覆盖语义）。
     *
     * <p>内置角色拒绝修改；校验与落库在同一事务，并锁定角色行。没有任何变化时不写审计。</p>
     */
    ProjectRoleDataScopeView saveRoleScopes(
            String projectId,
            String roleId,
            ProjectRoleDataScopeRequest request,
            KaiwuContext actor,
            RequestMetadata metadata);

    /** 项目登记的全部受控资源，含已下线的，按资源码排序。 */
    List<ProjectDataResourceView> resources(String projectId);

    /**
     * 按资源码新增或更新受控资源，并保持启用。
     *
     * <p>只写资源本身，不改任何角色的范围配置：授权不随代码下发（ADR 0044）。</p>
     *
     * @param allowedScopes 允许的范围类型，调用方保证来自清单解析的校验结果
     */
    void saveResource(String projectId, String code, String name, List<String> allowedScopes);

    /** 该资源上范围类型不在 {@code allowedScopes} 内的角色配置数，这些配置会按仅本人生效。 */
    long configsOutside(String projectId, String code, List<String> allowedScopes);

    /** 部门编码到部门 ID，只含存在的编码；配置移交按编码对齐各环境的部门。 */
    Map<String, String> departmentIdsByCode(Collection<String> codes);

    /** 部门 ID 到部门编码，只含存在的部门。 */
    Map<String, String> departmentCodesById(Collection<String> ids);
}
