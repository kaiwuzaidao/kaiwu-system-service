package com.kaiwu.module.project.repository;

import com.kaiwu.module.project.mapper.ProjectMemberQueryMapper;
import java.util.List;
import org.springframework.stereotype.Repository;

/** C3 成员资格查询数据边界。 */
@Repository
public class ProjectMemberQueryRepository {
    private final ProjectMemberQueryMapper mapper;
    /** 注入只读成员查询 Mapper。 */
    public ProjectMemberQueryRepository(ProjectMemberQueryMapper mapper) {
        this.mapper = mapper;
    }
    /** 校验路径项目是否等于凭据项目。 */
    public boolean matchesProject(String projectId, String code) {
        return mapper.matchesProject(projectId, code) == 1;
    }
    /** 判断指定项目的角色是否启用。 */
    public boolean activeRole(String projectId, String code) {
        return mapper.activeRole(projectId, code) == 1;
    }
    /** 获取有上限的角色成员。 */
    public List<String> membersByRole(String projectId, String role, int limit) {
        return mapper.membersByRole(projectId, role, limit);
    }
    /** 只返回指定 ID 中的有效成员。 */
    public List<String> eligibleMembers(String projectId, List<String> ids, String role) {
        return mapper.eligibleMembers(projectId, ids, role);
    }
}
