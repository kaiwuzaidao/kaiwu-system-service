package com.kaiwu.module.project.dto;

import jakarta.validation.constraints.NotNull;
import java.util.Set;

public record ProjectRoleMenuRequest(@NotNull(message = "菜单集合不能为空") Set<String> menuIds) {}
