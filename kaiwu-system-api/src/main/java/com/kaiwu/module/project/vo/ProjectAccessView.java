package com.kaiwu.module.project.vo;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

/**
 * 某个用户在某个业务项目下的入口授权快照（ADR 0003）。
 *
 * <p>Gateway 用它来决定「这个人能不能进这个项目」，以及签发 Context 时写入哪些项目事实。
 * 这里的 {@code projectId} 是**权威 ID**：客户端提交的 {@code X-Project-Id} 只能与它比对，
 * 不能反过来成为事实来源。</p>
 *
 * @param projectId        项目权威 ID，19 位数字的字符串形式
 * @param projectCode      项目编码，与 Route 绑定的稳定标识
 * @param permissions      该用户在本项目下的权限码
 * @param projectRoleCodes 该用户在本项目下的角色编码
 * @param dataScope        数据范围（ADR 0044）；项目没有启用的受控资源时为空，JSON 里不出现该键，
 *                         此时响应与引入数据范围之前完全一致
 */
public record ProjectAccessView(
        String projectId,
        String projectCode,
        List<String> permissions,
        List<String> projectRoleCodes,
        @JsonInclude(JsonInclude.Include.NON_NULL) DataScopeView dataScope) {

    /** 不带数据范围的快照，既有调用方沿用。 */
    public ProjectAccessView(
            String projectId, String projectCode, List<String> permissions, List<String> projectRoleCodes) {
        this(projectId, projectCode, permissions, projectRoleCodes, null);
    }
}
