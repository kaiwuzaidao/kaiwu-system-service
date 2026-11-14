package com.kaiwu.module.connector.dto.request;

import jakarta.validation.constraints.NotBlank;

/**
 * 修改项目存储绑定状态。
 *
 * @param status 目标状态，取字典 {@code storage.binding.status}
 */
public record ProjectStorageStatusRequest(@NotBlank(message = "状态不能为空") String status) {}
