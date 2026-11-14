package com.kaiwu.module.connector.vo;

import java.util.List;

/**
 * 一次签发返回的本项目全部可用存储凭证。
 *
 * @param projectCode 项目编码
 * @param credentials 已签发的凭证，包含生效与只读绑定
 * @param unavailable 本次未能签发的存储名；原因只记录在 System 日志里，不下发
 */
public record StorageCredentialBundleView(
        String projectCode, List<StorageCredentialView> credentials, List<String> unavailable) {}
