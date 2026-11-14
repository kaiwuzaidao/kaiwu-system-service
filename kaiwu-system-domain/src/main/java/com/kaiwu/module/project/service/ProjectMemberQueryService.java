package com.kaiwu.module.project.service;

import com.kaiwu.module.project.vo.ProjectMemberEligibilityResult;
import com.kaiwu.module.project.vo.ProjectMemberRoleResult;
import java.util.List;

/** 面向后台候选解析的受限项目成员查询。 */
public interface ProjectMemberQueryService {
    /** 完整返回角色有效成员，超过上限整体失败。 */
    ProjectMemberRoleResult byRole(String authorization, String projectCode, String roleCode);
    /** 按原始候选集合核实当前有效资格。 */
    ProjectMemberEligibilityResult eligibility(
            String authorization, String projectCode, List<String> userIds, String roleCode);
}
