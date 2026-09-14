package com.kaiwu.module.project.dto;

import jakarta.validation.constraints.*;

public record ProjectMenuRequest(
        String parentId,
        @NotBlank(message = "菜单名称不能为空") @Size(max = 100, message = "菜单名称不能超过 100 个字符") String menuName,
        /** 引用的国际化资源 key；非空即启用引用式国际化（ADR 0013） */
        String menuNameKey,
        @NotBlank(message = "菜单类型不能为空") @Pattern(regexp = "DIR|MENU|BUTTON", message = "菜单类型非法") String menuType,
        @Size(max = 256, message = "路由路径不能超过 256 个字符") String routePath,
        @Size(max = 256, message = "组件路径不能超过 256 个字符") String componentPath,
        @Size(max = 128, message = "权限码不能超过 128 个字符") String permissionCode,
        @Size(max = 64, message = "菜单图标不能超过 64 个字符") String icon,
        @NotNull(message = "排序号不能为空")
                @Min(value = 0, message = "排序号不能小于 0")
                @Max(value = 9999, message = "排序号不能大于 9999")
                Integer sortNo,
        @NotNull(message = "是否显示不能为空") Boolean visible) {}
