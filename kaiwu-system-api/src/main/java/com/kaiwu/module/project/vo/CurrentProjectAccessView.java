package com.kaiwu.module.project.vo;

import java.util.List;
import java.util.Set;

/**
 * 当前用户在某项目下的访问上下文。
 *
 * <p>{@code userLocale} 让内嵌业务前端跟随平台语言：业务前端启动时本就要调本接口，
 * 复用它可以避免多一次请求，也避免业务前端自建语言状态与平台不同步。</p>
 */
public record CurrentProjectAccessView(
        ProjectView project,
        Set<String> roleCodes,
        Set<String> permissions,
        List<ProjectMenuView> menus,
        String userLocale) {}
