package com.kaiwu.port;

/** 仅暴露“用户是否为项目有效成员”，避免调度模块依赖项目仓储。 */
public interface ProjectMembershipPort {

    boolean activeMemberExists(String projectId, String userId);
}
