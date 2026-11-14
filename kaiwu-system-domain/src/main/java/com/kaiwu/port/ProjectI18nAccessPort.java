package com.kaiwu.port;

/** 项目级国际化资源的写入边界：只确认用户是该业务项目的有效项目管理员。 */
public interface ProjectI18nAccessPort {

    /** 非业务项目、项目停用或用户不是有效项目管理员时抛出 ApiException。 */
    void requireProjectAdmin(String projectId, String userId);
}
