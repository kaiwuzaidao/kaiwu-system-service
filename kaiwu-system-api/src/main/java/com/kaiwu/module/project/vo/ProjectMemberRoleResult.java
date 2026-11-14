package com.kaiwu.module.project.vo;

import java.util.List;

/** 某角色的完整候选用户 ID 列表。 */
public record ProjectMemberRoleResult(String roleCode, List<String> userIds) {}
