package com.kaiwu.module.connector.service;

import com.kaiwu.module.connector.vo.StorageCredentialBundleView;

/**
 * 按项目签发对象存储临时凭证（ADR 0039 第 2 节）。长期密钥不离开本服务。
 */
public interface StorageCredentialService {

    /**
     * 为项目全部生效与只读绑定签发临时凭证。单个绑定签发失败不影响其他绑定。
     *
     * @param projectId 项目 ID，必须来自已校验的项目服务凭据，不得由调用方传入
     * @return 本项目的凭证集合
     */
    StorageCredentialBundleView issue(String projectId);
}
