package com.kaiwu.module.connector.service.impl;

import static org.springframework.http.HttpStatus.BAD_REQUEST;
import static org.springframework.http.HttpStatus.CONFLICT;
import static org.springframework.http.HttpStatus.NOT_FOUND;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.LongIdGenerator;
import com.kaiwu.module.connector.client.AliyunStsCredentialIssuer;
import com.kaiwu.module.connector.client.StorageAccountAccess;
import com.kaiwu.module.connector.client.StorageNetworkPolicy;
import com.kaiwu.module.connector.client.StorageObjectProbe;
import com.kaiwu.module.connector.client.TemporaryCredential;
import com.kaiwu.module.connector.dto.request.ProjectStorageBindRequest;
import com.kaiwu.module.connector.dto.request.StorageAccountSaveRequest;
import com.kaiwu.module.connector.entity.ProjectStorageRow;
import com.kaiwu.module.connector.entity.StorageAccountRow;
import com.kaiwu.module.connector.mapper.ProjectStorageMapper;
import com.kaiwu.module.connector.mapper.StorageAccountMapper;
import com.kaiwu.module.connector.service.StorageService;
import com.kaiwu.module.connector.vo.ProjectStorageBindingView;
import com.kaiwu.module.connector.vo.StorageAccountView;
import com.kaiwu.module.connector.vo.StorageConnectionTestView;
import java.net.URI;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 存储账号与项目绑定的管理实现（ADR 0039 第 4、5 节）。
 */
@Service
public class StorageServiceImpl implements StorageService {

    private static final String ACTIVE = "ACTIVE";
    private static final Set<String> BINDING_STATUSES = Set.of(ACTIVE, "READ_ONLY", "DISABLED");
    private static final String DEFAULT_STORAGE_NAME = "default";
    private static final long DEFAULT_MAX_OBJECT_BYTES = 20L * 1024 * 1024;
    private static final int DEFAULT_TTL_SECONDS = 1800;
    private static final int PROBE_TTL_SECONDS = 900;
    private static final int MAX_TEST_MESSAGE_LENGTH = 500;
    private static final Pattern CONTENT_TYPE =
            Pattern.compile("[a-z0-9][a-z0-9!#$&^_.+-]{0,63}/[a-z0-9*][a-z0-9!#$&^_.+*-]{0,63}");

    private final StorageAccountMapper accountMapper;
    private final ProjectStorageMapper bindingMapper;
    private final StorageSupport support;
    private final StorageNetworkPolicy networkPolicy;
    private final StorageObjectProbe probe;
    private final Clock clock;

    /**
     * 创建管理服务。
     *
     * @param accountMapper 账号 Mapper
     * @param bindingMapper 绑定 Mapper
     * @param support 签发器与加解密协作者
     * @param networkPolicy 出站管控，保存时提前校验地址
     * @param probe 测试连接用的对象探测器
     * @param clock 时间来源
     */
    public StorageServiceImpl(
            StorageAccountMapper accountMapper,
            ProjectStorageMapper bindingMapper,
            StorageSupport support,
            StorageNetworkPolicy networkPolicy,
            StorageObjectProbe probe,
            Clock clock) {
        this.accountMapper = accountMapper;
        this.bindingMapper = bindingMapper;
        this.support = support;
        this.networkPolicy = networkPolicy;
        this.probe = probe;
        this.clock = clock;
    }

    /**
     * 列出账号并脱敏。
     *
     * @return 账号视图
     */
    @Override
    public List<StorageAccountView> listAccounts() {
        return accountMapper.listAccounts().stream()
                .map(StorageServiceImpl::toView)
                .toList();
    }

    /**
     * 校验并保存账号；Secret 加密后落库，修改时留空沿用原密文。
     *
     * @param id 账号 ID，为空表示新建
     * @param request 账号参数
     * @param operatorId 操作人 ID
     * @return 保存后的账号视图
     */
    @Override
    @Transactional
    public StorageAccountView saveAccount(String id, StorageAccountSaveRequest request, String operatorId) {
        String providerType = request.providerType().trim();
        if (!support.supports(providerType)) {
            throw badRequest("不支持的存储类型：" + providerType);
        }
        String endpoint = normalizeEndpoint(request.endpoint(), "存储地址");
        String stsEndpoint = normalizeEndpoint(request.stsEndpoint(), "STS 地址");
        boolean pathStyle = Boolean.TRUE.equals(request.pathStyle());
        String roleArn = blankToNull(request.roleArn());
        if (AliyunStsCredentialIssuer.PROVIDER_TYPE.equals(providerType)) {
            if (roleArn == null) {
                throw badRequest("阿里云存储账号必须配置角色 ARN");
            }
            if (pathStyle) {
                throw badRequest("阿里云 OSS 不支持 path-style 访问");
            }
        }
        StorageAccountRow existing = id == null ? null : requireAccount(id);
        String secret = blankToNull(request.accessKeySecret());
        String ciphertext;
        if (secret != null) {
            ciphertext = support.encrypt(secret);
        } else if (existing != null) {
            ciphertext = existing.accessKeySecretCiphertext();
        } else {
            throw badRequest("新建账号必须填写 AccessKey Secret");
        }
        String accessKeyId = blankToNull(request.accessKeyId());
        if (accessKeyId == null && existing == null) {
            throw badRequest("新建账号必须填写 AccessKey ID");
        }
        if (accessKeyId == null) {
            accessKeyId = existing.accessKeyId();
        }
        String accountCode = existing == null ? request.accountCode().trim() : existing.accountCode();
        if (existing == null && accountMapper.findAccountByCode(accountCode) != null) {
            throw new ApiException(CONFLICT, "账号编码已存在：" + accountCode, "api.common.conflict");
        }
        StorageAccountRow row = new StorageAccountRow(
                existing == null ? LongIdGenerator.nextId() : existing.id(),
                accountCode,
                request.accountName().trim(),
                providerType,
                endpoint,
                request.region().trim(),
                request.bucket().trim(),
                pathStyle,
                stsEndpoint,
                roleArn,
                accessKeyId,
                ciphertext,
                request.credentialTtlSeconds() == null ? DEFAULT_TTL_SECONDS : request.credentialTtlSeconds(),
                request.enabled() == null || request.enabled() ? "ENABLED" : "DISABLED",
                null,
                null,
                null,
                0);
        if (existing == null) {
            accountMapper.insertAccount(row, operatorId);
        } else {
            accountMapper.updateAccount(row);
        }
        return toView(requireAccount(row.id()));
    }

    /**
     * 针对保留探测前缀签发凭证并写删探测对象。
     *
     * @param id 账号 ID
     * @return 测试结果
     */
    @Override
    public StorageConnectionTestView testAccount(String id) {
        StorageAccountRow row = requireAccount(id);
        LocalDateTime testedAt = LocalDateTime.now(clock);
        long start = System.nanoTime();
        boolean success = false;
        String message;
        try {
            StorageAccountAccess access = support.access(row);
            TemporaryCredential credential = support.issuer(row.providerType())
                    .assumeRole(
                            access,
                            StorageSupport.sessionName("probe"),
                            StorageObjectProbe.PROBE_PREFIX,
                            false,
                            PROBE_TTL_SECONDS);
            probe.writeAndDelete(access, credential);
            success = true;
            message = "连接成功：已签发临时凭证并完成一次对象写入与删除";
        } catch (IllegalStateException | SecurityException exception) {
            message = exception.getMessage();
        } catch (RuntimeException exception) {
            message = "连接测试失败（" + exception.getClass().getSimpleName() + "）";
        }
        long latency = Math.max(0, (System.nanoTime() - start) / 1_000_000);
        accountMapper.recordTest(
                id, success ? "SUCCESS" : "FAILED", truncate(message, MAX_TEST_MESSAGE_LENGTH), testedAt);
        return new StorageConnectionTestView(success, latency, message, testedAt);
    }

    /**
     * 列出绑定。
     *
     * @param projectId 项目 ID，可空
     * @return 绑定视图
     */
    @Override
    public List<ProjectStorageBindingView> listBindings(String projectId) {
        return bindingMapper.listBindings(blankToNull(projectId)).stream()
                .map(StorageServiceImpl::toView)
                .toList();
    }

    /**
     * 在事务内锁定当前生效绑定后切换，保证同一存储名同时只有一条生效绑定。
     *
     * @param request 绑定参数
     * @return 当前生效的绑定
     */
    @Override
    @Transactional
    public ProjectStorageBindingView bind(ProjectStorageBindRequest request) {
        String projectId = request.projectId().trim();
        String projectCode = bindingMapper.findProjectCode(projectId);
        if (projectCode == null) {
            throw new ApiException(NOT_FOUND, "项目不存在", "api.common.notFound");
        }
        if (projectCode.startsWith("_")) {
            throw badRequest("项目编码不能以下划线开头，该前缀保留给平台探测使用");
        }
        StorageAccountRow account = requireAccount(request.accountId().trim());
        if (!account.enabled()) {
            throw badRequest("存储账号已停用，不能绑定");
        }
        String storageName =
                request.storageName() == null || request.storageName().isBlank()
                        ? DEFAULT_STORAGE_NAME
                        : request.storageName().trim();
        long maxObjectBytes = request.maxObjectBytes() == null ? DEFAULT_MAX_OBJECT_BYTES : request.maxObjectBytes();
        String contentTypes = normalizeContentTypes(request.allowedContentTypes());
        ProjectStorageRow active = bindingMapper.lockActive(projectId, storageName);
        if (active != null && active.accountId().equals(account.id())) {
            bindingMapper.updateLimits(active.id(), maxObjectBytes, contentTypes);
            return toView(bindingMapper.findBinding(active.id()));
        }
        if (active != null) {
            bindingMapper.updateStatus(active.id(), "READ_ONLY");
        }
        String id = LongIdGenerator.nextId();
        try {
            bindingMapper.insertBinding(id, projectId, storageName, account.id(), ACTIVE, maxObjectBytes, contentTypes);
        } catch (DuplicateKeyException duplicate) {
            throw new ApiException(CONFLICT, "该存储名正在被其他操作切换，请刷新后重试", "api.common.conflict");
        }
        return toView(bindingMapper.findBinding(id));
    }

    /**
     * 修改绑定状态；改为生效前确认没有其他生效绑定。
     *
     * @param id 绑定 ID
     * @param status 目标状态
     * @return 修改后的绑定
     */
    @Override
    @Transactional
    public ProjectStorageBindingView changeBindingStatus(String id, String status) {
        String target = status == null ? "" : status.trim().toUpperCase(Locale.ROOT);
        if (!BINDING_STATUSES.contains(target)) {
            throw badRequest("不支持的绑定状态：" + status);
        }
        ProjectStorageRow binding = bindingMapper.findBinding(id);
        if (binding == null) {
            throw new ApiException(NOT_FOUND, "存储绑定不存在", "api.common.notFound");
        }
        if (ACTIVE.equals(target)) {
            ProjectStorageRow active = bindingMapper.lockActive(binding.projectId(), binding.storageName());
            if (active != null && !active.id().equals(id)) {
                throw new ApiException(CONFLICT, "该存储名已有生效绑定，请先把它改为只读", "api.common.conflict");
            }
        }
        try {
            bindingMapper.updateStatus(id, target);
        } catch (DuplicateKeyException duplicate) {
            throw new ApiException(CONFLICT, "该存储名已有生效绑定，请刷新后重试", "api.common.conflict");
        }
        return toView(bindingMapper.findBinding(id));
    }

    /**
     * 读取账号，不存在时返回 404。
     *
     * @param id 账号 ID
     * @return 账号行
     */
    private StorageAccountRow requireAccount(String id) {
        StorageAccountRow row = accountMapper.findAccount(id);
        if (row == null) {
            throw new ApiException(NOT_FOUND, "存储账号不存在", "api.common.notFound");
        }
        return row;
    }

    /**
     * 校验地址格式并提前检查出站白名单，避免保存一个 System 永远无法连接的地址。
     *
     * @param value 管理员输入
     * @param label 字段名，用于错误消息
     * @return 去掉末尾斜杠的地址
     */
    private String normalizeEndpoint(String value, String label) {
        String candidate = value.trim();
        while (candidate.endsWith("/")) {
            candidate = candidate.substring(0, candidate.length() - 1);
        }
        URI uri;
        try {
            uri = URI.create(candidate);
        } catch (IllegalArgumentException exception) {
            throw badRequest(label + "格式不正确");
        }
        if (uri.getHost() == null
                || uri.getUserInfo() != null
                || uri.getQuery() != null
                || uri.getFragment() != null
                || (uri.getRawPath() != null && !uri.getRawPath().isEmpty())) {
            throw badRequest(label + "必须是不带路径的 HTTP(S) 地址");
        }
        try {
            networkPolicy.verify(uri);
        } catch (SecurityException exception) {
            throw badRequest(label + "不可用：" + exception.getMessage());
        }
        return candidate;
    }

    /**
     * 规范化允许的 MIME 类型列表。
     *
     * @param values 管理员输入，可空
     * @return 逗号分隔的小写 MIME 类型，为空时返回 {@code null}
     */
    private static String normalizeContentTypes(List<String> values) {
        if (values == null || values.isEmpty()) {
            return null;
        }
        List<String> normalized = values.stream()
                .filter(value -> value != null && !value.isBlank())
                .map(value -> value.trim().toLowerCase(Locale.ROOT))
                .distinct()
                .toList();
        for (String value : normalized) {
            if (!CONTENT_TYPE.matcher(value).matches()) {
                throw badRequest("MIME 类型格式不正确：" + value);
            }
        }
        return normalized.isEmpty() ? null : String.join(",", normalized);
    }

    /**
     * 账号行转视图，AccessKey ID 只保留首尾各 4 位。
     *
     * @param row 账号行
     * @return 账号视图
     */
    private static StorageAccountView toView(StorageAccountRow row) {
        String keyId = row.accessKeyId();
        String masked =
                keyId.length() > 8 ? keyId.substring(0, 4) + "****" + keyId.substring(keyId.length() - 4) : "****";
        return new StorageAccountView(
                row.id(),
                row.accountCode(),
                row.accountName(),
                row.providerType(),
                row.endpoint(),
                row.region(),
                row.bucket(),
                row.pathStyle(),
                row.stsEndpoint(),
                row.roleArn(),
                masked,
                row.accessKeySecretCiphertext() != null
                        && !row.accessKeySecretCiphertext().isBlank(),
                row.credentialTtlSeconds(),
                row.enabled(),
                row.bindingCount(),
                row.lastTestStatus(),
                row.lastTestMessage(),
                row.lastTestAt());
    }

    /**
     * 绑定行转视图。
     *
     * @param row 绑定行
     * @return 绑定视图
     */
    static ProjectStorageBindingView toView(ProjectStorageRow row) {
        return new ProjectStorageBindingView(
                row.id(),
                row.projectId(),
                row.projectCode(),
                row.projectName(),
                row.storageName(),
                row.accountId(),
                row.accountName(),
                row.bucket(),
                row.status(),
                row.maxObjectBytes(),
                splitContentTypes(row.allowedContentTypes()),
                row.createdAt());
    }

    /**
     * 拆分逗号分隔的 MIME 类型。
     *
     * @param value 存储值，可空
     * @return 类型列表，为空时返回空列表
     */
    static List<String> splitContentTypes(String value) {
        return value == null || value.isBlank() ? List.of() : List.of(value.split(","));
    }

    /**
     * 空白字符串转为 {@code null}。
     *
     * @param value 原值
     * @return 去空白后的值或 {@code null}
     */
    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    /**
     * 截断到列宽。
     *
     * @param value 原值
     * @param max 最大长度
     * @return 截断后的值
     */
    private static String truncate(String value, int max) {
        return value == null || value.length() <= max ? value : value.substring(0, max);
    }

    /**
     * 构造 400 异常。
     *
     * @param message 面向管理员的说明
     * @return 异常
     */
    private static ApiException badRequest(String message) {
        return new ApiException(BAD_REQUEST, message, "api.common.badRequest");
    }
}
