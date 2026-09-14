package com.kaiwu.module.project.vo;

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
 */
public record ProjectAccessView(
        String projectId, String projectCode, List<String> permissions, List<String> projectRoleCodes) {}
