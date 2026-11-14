package com.kaiwu.module.connector.service.impl;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.module.configuration.service.ConfigEncryptionService;
import com.kaiwu.module.connector.client.StorageAccountAccess;
import com.kaiwu.module.connector.client.StorageCredentialIssuer;
import com.kaiwu.module.connector.client.TemporaryCredential;
import com.kaiwu.module.connector.entity.ProjectStorageRow;
import com.kaiwu.module.connector.entity.StorageAccountRow;
import com.kaiwu.module.connector.mapper.ProjectStorageMapper;
import com.kaiwu.module.connector.mapper.StorageAccountMapper;
import com.kaiwu.module.connector.vo.StorageCredentialBundleView;
import com.kaiwu.module.connector.vo.StorageCredentialView;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * 验证按项目签发的边界（约束 storage.no-long-term-key-delivery）：前缀由项目编码决定、
 * 只读绑定只签读权限、签发结果绝不携带账号的长期密钥、单个绑定失败不影响其他绑定。
 */
class StorageCredentialServiceImplTest {

    private static final String LONG_TERM_KEY_ID = "LTAI-long-term-id";
    private static final String LONG_TERM_SECRET = "long-term-secret-plain";

    private final StorageAccountMapper accounts = mock(StorageAccountMapper.class);
    private final ProjectStorageMapper bindings = mock(ProjectStorageMapper.class);
    private final ConfigEncryptionService encryption = mock(ConfigEncryptionService.class);
    private final StorageCredentialIssuer issuer = mock(StorageCredentialIssuer.class);

    /**
     * 组装待测服务：一个 S3 兼容签发器，解密返回固定明文。
     *
     * @return 待测服务
     */
    private StorageCredentialServiceImpl service() {
        when(issuer.providerType()).thenReturn("S3_COMPATIBLE_STS");
        when(encryption.decrypt("cipher")).thenReturn(LONG_TERM_SECRET);
        return new StorageCredentialServiceImpl(accounts, bindings, new StorageSupport(List.of(issuer), encryption));
    }

    /**
     * 构造账号行。
     *
     * @param id 账号 ID
     * @param status 账号状态
     * @return 账号行
     */
    private static StorageAccountRow account(String id, String status) {
        return new StorageAccountRow(
                id,
                "code-" + id,
                "账号",
                "S3_COMPATIBLE_STS",
                "http://minio:9000",
                "us-east-1",
                "files",
                true,
                "http://minio:9000",
                null,
                LONG_TERM_KEY_ID,
                "cipher",
                1800,
                status,
                null,
                null,
                null,
                1);
    }

    /**
     * 构造绑定行。
     *
     * @param id 绑定 ID
     * @param name 存储名
     * @param accountId 账号 ID
     * @param status 绑定状态
     * @return 绑定行
     */
    private static ProjectStorageRow binding(String id, String name, String accountId, String status) {
        return new ProjectStorageRow(
                id,
                "1",
                "demo",
                "Demo",
                name,
                accountId,
                "账号",
                "files",
                status,
                1024,
                "image/png,application/pdf",
                LocalDateTime.now());
    }

    /** 读写与只读绑定各签一次，前缀固定为项目编码，结果里没有任何长期密钥。 */
    @Test
    void issuesScopedCredentialsWithoutLeakingLongTermKeys() {
        StorageCredentialServiceImpl service = service();
        when(bindings.findProjectCode("1")).thenReturn("demo");
        when(bindings.listIssuable("1"))
                .thenReturn(
                        List.of(binding("11", "default", "a", "ACTIVE"), binding("10", "default", "b", "READ_ONLY")));
        when(accounts.findAccount("a")).thenReturn(account("a", "ENABLED"));
        when(accounts.findAccount("b")).thenReturn(account("b", "ENABLED"));
        when(issuer.assumeRole(any(), anyString(), anyString(), anyBoolean(), anyInt()))
                .thenReturn(new TemporaryCredential(
                        "STS-AK", "STS-SK", "STS-TOKEN", Instant.parse("2026-10-29T09:00:00Z")));

        StorageCredentialBundleView bundle = service.issue("1");

        assertThat(bundle.projectCode()).isEqualTo("demo");
        assertThat(bundle.credentials())
                .extracting(StorageCredentialView::mode)
                .containsExactly("READ_WRITE", "READ_ONLY");
        assertThat(bundle.credentials()).allSatisfy(view -> {
            assertThat(view.prefix()).isEqualTo("demo/");
            assertThat(view.accessKeyId()).isEqualTo("STS-AK");
            assertThat(view.allowedContentTypes()).containsExactly("image/png", "application/pdf");
            assertThat(String.join("|", view.accessKeyId(), view.accessKeySecret(), view.securityToken()))
                    .doesNotContain(LONG_TERM_KEY_ID, LONG_TERM_SECRET);
            assertThat(view.toString()).doesNotContain("STS-SK", "STS-TOKEN");
        });
        verify(issuer).assumeRole(any(StorageAccountAccess.class), eq("kaiwu-demo"), eq("demo/"), eq(false), eq(1800));
        verify(issuer).assumeRole(any(StorageAccountAccess.class), eq("kaiwu-demo"), eq("demo/"), eq(true), eq(1800));
    }

    /** 账号停用或签发失败的绑定进入 unavailable，其余绑定照常签发。 */
    @Test
    void failuresAreIsolatedPerBinding() {
        StorageCredentialServiceImpl service = service();
        when(bindings.findProjectCode("1")).thenReturn("demo");
        when(bindings.listIssuable("1"))
                .thenReturn(List.of(
                        binding("1", "default", "ok", "ACTIVE"),
                        binding("2", "archive", "off", "ACTIVE"),
                        binding("3", "broken", "bad", "ACTIVE")));
        when(accounts.findAccount("ok")).thenReturn(account("ok", "ENABLED"));
        when(accounts.findAccount("off")).thenReturn(account("off", "DISABLED"));
        when(accounts.findAccount("bad")).thenReturn(account("bad", "ENABLED"));
        when(issuer.assumeRole(any(), anyString(), anyString(), anyBoolean(), anyInt()))
                .thenReturn(new TemporaryCredential("AK", "SK", "TK", Instant.now()))
                .thenThrow(new IllegalStateException("STS 签发失败（HTTP 403，AccessDenied）"));

        StorageCredentialBundleView bundle = service.issue("1");

        assertThat(bundle.credentials())
                .extracting(StorageCredentialView::storageName)
                .containsExactly("default");
        assertThat(bundle.unavailable()).containsExactly("archive", "broken");
    }
}
