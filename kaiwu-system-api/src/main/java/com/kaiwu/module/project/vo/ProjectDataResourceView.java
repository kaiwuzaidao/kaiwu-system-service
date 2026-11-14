package com.kaiwu.module.project.vo;

import java.util.List;

/**
 * 项目登记的受控数据资源（ADR 0044）。
 *
 * @param code          资源码
 * @param name          管理端展示名
 * @param allowedScopes 允许选择的范围类型，按枚举顺序，必含 {@code SELF}
 * @param status        {@code ENABLED} 或 {@code DISABLED}
 */
public record ProjectDataResourceView(String code, String name, List<String> allowedScopes, String status) {}
