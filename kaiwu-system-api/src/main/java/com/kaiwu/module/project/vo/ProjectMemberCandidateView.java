package com.kaiwu.module.project.vo;

/**
 * 添加项目成员时可选的用户。
 *
 * <p>只含选人所需的最少字段：不带邮箱、状态、创建时间等。项目管理员没有平台级用户管理权限，
 * 不应借选人接口读到用户的其它资料。</p>
 */
public record ProjectMemberCandidateView(String userId, String username, String displayName) {}
