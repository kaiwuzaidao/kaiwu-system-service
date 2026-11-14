package com.kaiwu.module.project.model;

/** 已认证服务身份；调用方不得取得凭据哈希或明文。 */
public record ProjectServiceCredential(String id, String projectId, String serviceCode) {}
