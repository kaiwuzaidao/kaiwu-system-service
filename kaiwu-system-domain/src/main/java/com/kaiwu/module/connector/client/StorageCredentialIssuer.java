package com.kaiwu.module.connector.client;

/**
 * 某一类存储的 STS 签发器（ADR 0039 第 3 节）。新增存储类型时实现本接口并注册为 Bean。
 *
 * <p>实现必须：只通过 {@link StorageNetworkPolicy} 出站；错误消息不得包含任何密钥、签名或令牌；
 * 会话策略必须把权限限定在 {@code {bucket}/{prefix}*}。
 */
public interface StorageCredentialIssuer {

    /**
     * 本签发器负责的存储类型，对应字典 {@code storage.provider.type} 的值。
     *
     * @return 存储类型
     */
    String providerType();

    /**
     * 扮演角色并签发附带会话策略的临时凭证。
     *
     * @param account 已解密的账号参数
     * @param sessionName 会话名，用于云端审计追溯到项目
     * @param prefix 对象 key 前缀，形如 {@code demo/}
     * @param readOnly 是否只授予读权限
     * @param ttlSeconds 有效期（秒）
     * @return 临时凭证
     * @throws IllegalStateException 签发失败时抛出，消息可直接展示
     */
    TemporaryCredential assumeRole(
            StorageAccountAccess account, String sessionName, String prefix, boolean readOnly, int ttlSeconds);
}
