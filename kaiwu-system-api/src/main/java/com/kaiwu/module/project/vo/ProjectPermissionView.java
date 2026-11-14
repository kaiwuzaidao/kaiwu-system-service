package com.kaiwu.module.project.vo;

/**
 * 项目内可授予的权限码。
 *
 * <p>命令行与 AI 工具按权限码给角色授权，不需要认识菜单 ID；这里把按钮节点拍平成「码、名称、所属菜单」。</p>
 */
public record ProjectPermissionView(String code, String name, String menuName) {}
