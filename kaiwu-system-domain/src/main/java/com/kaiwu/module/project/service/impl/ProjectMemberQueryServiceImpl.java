package com.kaiwu.module.project.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.project.model.ProjectServiceCredential;
import com.kaiwu.module.project.repository.ProjectMemberQueryRepository;
import com.kaiwu.module.project.service.ProjectMemberQueryService;
import com.kaiwu.module.project.service.ProjectServiceCredentials;
import com.kaiwu.module.project.vo.ProjectMemberEligibilityResult;
import com.kaiwu.module.project.vo.ProjectMemberRoleResult;
import java.util.List;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** 限定项目与 scope 的候选成员查询，不参与用户办理授权。 */
@Service
public class ProjectMemberQueryServiceImpl implements ProjectMemberQueryService {
    private final ProjectServiceCredentials credentials;
    private final ProjectMemberQueryRepository repository;
    private final int limit;

    /** 候选数量设置有硬上限，避免完整返回造成资源耗尽。 */
    public ProjectMemberQueryServiceImpl(
            ProjectServiceCredentials credentials,
            ProjectMemberQueryRepository repository,
            @Value("${kaiwu.project-members.candidate-limit:200}") int limit) {
        if (limit < 1 || limit > 200) throw new IllegalArgumentException("invalid candidate limit");
        this.credentials = credentials;
        this.repository = repository;
        this.limit = limit;
    }

    /** 整体返回指定角色的有效成员，超限不得返回部分数据。 */
    @Transactional(readOnly = true)
    public ProjectMemberRoleResult byRole(String authorization, String projectCode, String roleCode) {
        ProjectServiceCredential identity = authorize(authorization, projectCode);
        validateRole(roleCode);
        requireRole(identity.projectId(), roleCode);
        List<String> users = repository.membersByRole(identity.projectId(), roleCode, limit + 1);
        if (users.size() > limit) throw tooMany();
        return new ProjectMemberRoleResult(roleCode, List.copyOf(users));
    }

    /** 批量检查给定用户，不返回无关成员或个人资料。 */
    @Transactional(readOnly = true)
    public ProjectMemberEligibilityResult eligibility(
            String authorization, String projectCode, List<String> userIds, String roleCode) {
        ProjectServiceCredential identity = authorize(authorization, projectCode);
        if (userIds == null
                || userIds.isEmpty()
                || userIds.size() > limit
                || userIds.stream()
                        .anyMatch(id -> id == null
                                || (!id.matches("[1-9][0-9]{0,18}")
                                        || new java.math.BigInteger(id)
                                                        .compareTo(java.math.BigInteger.valueOf(Long.MAX_VALUE))
                                                > 0))) {
            throw badRequest();
        }
        if (roleCode != null) {
            validateRole(roleCode);
            requireRole(identity.projectId(), roleCode);
        }
        List<String> unique = userIds.stream().distinct().toList();
        Set<String> eligible = Set.copyOf(repository.eligibleMembers(identity.projectId(), unique, roleCode));
        return new ProjectMemberEligibilityResult(unique.stream()
                .map(id -> new ProjectMemberEligibilityResult.Item(id, eligible.contains(id)))
                .toList());
    }

    /** 先认证member:read，再以数据库项目编码核对路径归属，不接受调用方身份头。 */
    private ProjectServiceCredential authorize(String authorization, String projectCode) {
        var identity = credentials.authenticateScopeBearer(authorization, "member:read");
        if (projectCode == null || !projectCode.matches("[a-z][a-z0-9-]{1,63}")) throw badRequest();
        if (!repository.matchesProject(identity.projectId(), projectCode))
            throw new ApiException(HttpStatus.FORBIDDEN, "项目不匹配", "api.common.forbidden");
        return identity;
    }

    /** 角色编码只允许平台标识字符，不能作为SQL或其他项目路径输入。 */
    private void validateRole(String code) {
        if (code == null || !code.matches("[a-zA-Z0-9][a-zA-Z0-9:_-]{0,63}")) throw badRequest();
    }

    /** 不为不存在或停用的项目角色生成空候选成功响应。 */
    private void requireRole(String projectId, String role) {
        if (!repository.activeRole(projectId, role))
            throw new ApiException(HttpStatus.NOT_FOUND, "角色不存在或已停用", "api.common.notFound");
    }

    /** 输入无效时整体拒绝，既不截断候选也不忽略非法ID。 */
    private static ApiException badRequest() {
        return new ApiException(HttpStatus.BAD_REQUEST, "请求无效", "api.common.badRequest");
    }

    /** 超限保留明确422错误，不向调用方暴露部分候选快照。 */
    private static ApiException tooMany() {
        return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "候选人数超过上限", "project.members.candidateLimitExceeded");
    }
}
