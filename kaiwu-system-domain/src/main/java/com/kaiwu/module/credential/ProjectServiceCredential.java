package com.kaiwu.module.credential;

/**
 * 已校验的项目服务凭据。凭据只回答"是哪个项目"，具体能做什么由各能力自行判断。
 */
public record ProjectServiceCredential(String id, String projectId, String tokenHash, String status) {}
