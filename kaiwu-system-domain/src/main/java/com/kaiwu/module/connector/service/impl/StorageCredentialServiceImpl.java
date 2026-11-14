package com.kaiwu.module.connector.service.impl;

import static org.springframework.http.HttpStatus.NOT_FOUND;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.connector.client.TemporaryCredential;
import com.kaiwu.module.connector.entity.ProjectStorageRow;
import com.kaiwu.module.connector.entity.StorageAccountRow;
import com.kaiwu.module.connector.mapper.ProjectStorageMapper;
import com.kaiwu.module.connector.mapper.StorageAccountMapper;
import com.kaiwu.module.connector.service.StorageCredentialService;
import com.kaiwu.module.connector.vo.StorageCredentialBundleView;
import com.kaiwu.module.connector.vo.StorageCredentialView;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * 按项目签发临时凭证（ADR 0039 第 2 节）。
 *
 * <p>前缀固定为 {@code {projectCode}/}，由本服务根据项目服务凭据所属项目生成，调用方无法指定。
 * 签发结果只返回给调用方，不落库；日志只记录项目、绑定、模式与失效时间。
 */
@Service
public class StorageCredentialServiceImpl implements StorageCredentialService {

    private static final Logger log = LoggerFactory.getLogger(StorageCredentialServiceImpl.class);
    private static final String READ_ONLY = "READ_ONLY";

    private final StorageAccountMapper accountMapper;
    private final ProjectStorageMapper bindingMapper;
    private final StorageSupport support;

    /**
     * 创建签发服务。
     *
     * @param accountMapper 账号 Mapper
     * @param bindingMapper 绑定 Mapper
     * @param support 签发器与解密协作者
     */
    public StorageCredentialServiceImpl(
            StorageAccountMapper accountMapper, ProjectStorageMapper bindingMapper, StorageSupport support) {
        this.accountMapper = accountMapper;
        this.bindingMapper = bindingMapper;
        this.support = support;
    }

    /**
     * 逐个绑定签发；账号停用或签发失败的绑定记入 {@code unavailable}，不影响其他绑定。
     *
     * @param projectId 已校验凭据所属的项目 ID
     * @return 本项目的凭证集合
     */
    @Override
    public StorageCredentialBundleView issue(String projectId) {
        String projectCode = bindingMapper.findProjectCode(projectId);
        if (projectCode == null) {
            throw new ApiException(NOT_FOUND, "项目不存在", "api.common.notFound");
        }
        String prefix = projectCode + "/";
        List<StorageCredentialView> issued = new ArrayList<>();
        List<String> unavailable = new ArrayList<>();
        for (ProjectStorageRow binding : bindingMapper.listIssuable(projectId)) {
            StorageAccountRow account = accountMapper.findAccount(binding.accountId());
            if (account == null || !account.enabled()) {
                unavailable.add(binding.storageName());
                continue;
            }
            boolean readOnly = READ_ONLY.equals(binding.status());
            try {
                TemporaryCredential credential = support.issuer(account.providerType())
                        .assumeRole(
                                support.access(account),
                                StorageSupport.sessionName(projectCode),
                                prefix,
                                readOnly,
                                account.credentialTtlSeconds());
                issued.add(new StorageCredentialView(
                        binding.id(),
                        binding.storageName(),
                        readOnly ? "READ_ONLY" : "READ_WRITE",
                        account.providerType(),
                        account.endpoint(),
                        account.region(),
                        account.bucket(),
                        account.pathStyle(),
                        prefix,
                        binding.maxObjectBytes(),
                        StorageServiceImpl.splitContentTypes(binding.allowedContentTypes()),
                        credential.accessKeyId(),
                        credential.accessKeySecret(),
                        credential.securityToken(),
                        credential.expiresAt()));
                Instant expiresAt = credential.expiresAt();
                log.info(
                        "对象存储凭证已签发 project={} storageRef={} mode={} expiresAt={}",
                        projectCode,
                        binding.id(),
                        readOnly ? "READ_ONLY" : "READ_WRITE",
                        expiresAt);
            } catch (RuntimeException exception) {
                unavailable.add(binding.storageName());
                log.warn(
                        "对象存储凭证签发失败 project={} storageRef={} reason={}",
                        projectCode,
                        binding.id(),
                        exception.getMessage());
            }
        }
        return new StorageCredentialBundleView(projectCode, List.copyOf(issued), List.copyOf(unavailable));
    }
}
