package com.kaiwu.module.connector.service.impl;

import static org.springframework.http.HttpStatus.BAD_REQUEST;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.LongIdGenerator;
import com.kaiwu.module.ai.dto.AiProviderSaveRequest;
import com.kaiwu.module.ai.vo.AiProviderView;
import com.kaiwu.module.configuration.service.ConfigEncryptionService;
import com.kaiwu.module.connector.dto.AiModelRoutes;
import com.kaiwu.module.connector.dto.AiModelSaveRequest;
import com.kaiwu.module.connector.entity.AiModelRouteEntity;
import com.kaiwu.module.connector.repository.AiModelRouteRepository;
import com.kaiwu.module.connector.repository.AiProviderRepository;
import com.kaiwu.module.connector.repository.AiProviderRepository.ProviderRow;
import com.kaiwu.module.connector.service.AiProviderService;
import com.kaiwu.module.connector.vo.AiModelView;
import java.math.BigDecimal;
import java.net.URI;
import java.net.URISyntaxException;
import java.time.LocalDateTime;
import java.util.Locale;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * Applies validation, defaults, and secret handling around the provider config.
 */
@Service("aiProviderService")
public final class AiProviderServiceImpl implements AiProviderService {

    private static final BigDecimal DEFAULT_TEMPERATURE = new BigDecimal("0.2");
    private static final int DEFAULT_TIMEOUT_SECONDS = 60;

    private final AiProviderRepository repository;
    private final ConfigEncryptionService encryptionService;
    private final AiModelRouteRepository routes;

    public AiProviderServiceImpl(AiProviderRepository repository, ConfigEncryptionService encryptionService) {
        this(repository, encryptionService, null);
    }

    /** 注入模型存储、加密器和用途绑定存储。 */
    @Autowired
    public AiProviderServiceImpl(
            AiProviderRepository repository, ConfigEncryptionService encryptionService, AiModelRouteRepository routes) {
        this.repository = repository;
        this.encryptionService = encryptionService;
        this.routes = routes;
    }

    /** 管理页面读取的当前配置；API Key 以掩码返回，不外发明文。 */
    public AiProviderView current() {
        return repository
                .current()
                .map(this::toView)
                .orElseGet(() -> new AiProviderView(
                        "", "", false, "", DEFAULT_TEMPERATURE, DEFAULT_TIMEOUT_SECONDS, null, null, null));
    }

    /** 保存配置；提交掩码值表示「不修改 Key」，避免每次编辑都要重填密钥。 */
    public void save(AiProviderSaveRequest request) {
        if (request == null) {
            throw badRequest("AI 服务配置不能为空");
        }

        Optional<ProviderRow> previous = repository.current();
        String apiKeyCiphertext = selectCiphertext(request, previous);
        String baseUrl = normalizeAndValidateBaseUrl(request.baseUrl());
        requireExplicitKeyForNewEndpoint(previous, baseUrl, request.apiKey(), request.clearApiKey());

        repository.save(new ProviderRow(
                trimToEmpty(request.providerName()),
                baseUrl,
                apiKeyCiphertext,
                trimToEmpty(request.model()),
                request.temperature() == null ? DEFAULT_TEMPERATURE : request.temperature(),
                request.timeoutSeconds() == null ? DEFAULT_TIMEOUT_SECONDS : request.timeoutSeconds(),
                // ADR 0038 下线项目生成后页面不再提供启停开关；enabled 列随迁移压基线一并清理，这里固定写 true。
                true,
                null,
                null,
                null));
    }

    /** 供 AI 助手使用的运行期配置；未配置时返回空，由调用方决定如何降级。 */
    public Optional<RuntimeConfig> effective() {
        return repository
                .current()
                .map(row -> new RuntimeConfig(
                        row.providerName(),
                        normalizeAndValidateBaseUrl(row.baseUrl()),
                        decryptIfPresent(row.apiKeyCiphertext()),
                        row.model(),
                        row.temperature() == null ? DEFAULT_TEMPERATURE : row.temperature(),
                        row.timeoutSeconds()));
    }

    /** 输出不含密钥的模型列表。 */
    public java.util.List<AiModelView> models() {
        return repository.list().stream()
                .map(entity -> view(
                        Long.toString(entity.getId()),
                        repository.find(entity.getId()).orElseThrow()))
                .toList();
    }

    /** 保存模型并保护密钥不被页面回读。 */
    public AiModelView saveModel(AiModelSaveRequest request) {
        long id = request.id() == null || request.id().isBlank()
                ? Long.parseLong(LongIdGenerator.nextId())
                : parseId(request.id());
        Optional<ProviderRow> previous = repository.find(id);
        if (request.id() != null && !request.id().isBlank() && previous.isEmpty()) throw badRequest("模型不存在");
        AiProviderSaveRequest input = new AiProviderSaveRequest(
                request.providerName(),
                request.baseUrl(),
                request.apiKey(),
                request.clearApiKey(),
                request.model(),
                request.temperature(),
                request.timeoutSeconds());
        String baseUrl = normalizeAndValidateBaseUrl(request.baseUrl());
        requireExplicitKeyForNewEndpoint(previous, baseUrl, request.apiKey(), request.clearApiKey());
        ProviderRow row = new ProviderRow(
                trimToEmpty(request.providerName()),
                baseUrl,
                selectCiphertext(input, previous),
                trimToEmpty(request.model()),
                request.temperature() == null ? DEFAULT_TEMPERATURE : request.temperature(),
                request.timeoutSeconds() == null ? DEFAULT_TIMEOUT_SECONDS : request.timeoutSeconds(),
                true,
                null,
                null,
                null);
        repository.save(id, row);
        return view(Long.toString(id), row);
    }

    /** 返回当前用途绑定，空值表示使用原默认模型。 */
    public AiModelRoutes routes() {
        AiModelRouteEntity row = routes.current();
        if (row == null) throw new IllegalStateException("模型路由配置不存在，请检查数据库迁移");
        return new AiModelRoutes(idString(row.getPlanModelId()), idString(row.getAnswerModelId()));
    }

    /** 两个绑定同时提交，拒绝不存在的模型。 */
    public void saveRoutes(AiModelRoutes value) {
        Long plan = nullableId(value.planModelId());
        Long answer = nullableId(value.answerModelId());
        if ((plan != null && repository.find(plan).isEmpty())
                || (answer != null && repository.find(answer).isEmpty())) throw badRequest("所选模型不存在");
        routes.save(plan, answer);
    }

    /** 按固定 ID 读取运行配置，不输出给外部。 */
    public Optional<RuntimeConfig> effectiveModel(String id) {
        return repository.find(parseId(id)).map(this::toRuntime);
    }

    /** 明确绑定不可用时返回空，不切换到其他供应商。 */
    public Optional<RoutedConfig> effectiveFor(String purpose) {
        if (!"PLAN".equals(purpose) && !"ANSWER".equals(purpose))
            throw new IllegalArgumentException("unknown model purpose");
        AiModelRouteEntity row = routes.current();
        if (row == null) return Optional.empty();
        Long id = "PLAN".equals(purpose) ? row.getPlanModelId() : row.getAnswerModelId();
        long selected = id == null ? 1L : id;
        return repository
                .find(selected)
                .map(provider -> new RoutedConfig(Long.toString(selected), toRuntime(provider)));
    }

    /** 单次读取模型和修订号，保证测试结果归属于该版本。 */
    public Optional<TestConfig> prepareModelTest(String id) {
        return repository.findForTest(parseId(id)).map(row -> new TestConfig(toRuntime(row.row()), row.revision()));
    }

    /** 配置在测试期间变更时拒绝旧结果。 */
    public boolean recordModelTestIfRevision(
            String id, long revision, boolean success, String message, LocalDateTime testedAt) {
        return repository.recordTestIfRevision(parseId(id), revision, success, message, testedAt);
    }

    /** 将测试结果记录在对应模型上。 */
    public void recordModelTest(String id, boolean success, String message, LocalDateTime testedAt) {
        repository.recordTest(parseId(id), success, message, testedAt);
    }

    private RuntimeConfig toRuntime(ProviderRow row) {
        return new RuntimeConfig(
                row.providerName(),
                normalizeAndValidateBaseUrl(row.baseUrl()),
                decryptIfPresent(row.apiKeyCiphertext()),
                row.model(),
                row.temperature() == null ? DEFAULT_TEMPERATURE : row.temperature(),
                row.timeoutSeconds());
    }

    private AiModelView view(String id, ProviderRow row) {
        AiProviderView value = toView(row);
        return new AiModelView(
                id,
                value.providerName(),
                value.baseUrl(),
                value.apiKeyConfigured(),
                value.model(),
                value.temperature(),
                value.timeoutSeconds(),
                value.lastTestStatus(),
                value.lastTestMessage(),
                value.lastTestAt());
    }

    private static String idString(Long id) {
        return id == null ? null : Long.toString(id);
    }

    private static Long nullableId(String id) {
        return id == null || id.isBlank() ? null : parseId(id);
    }

    private static long parseId(String id) {
        try {
            long parsed = Long.parseLong(id);
            if (parsed <= 0) throw new NumberFormatException();
            return parsed;
        } catch (RuntimeException exception) {
            throw badRequest("模型编号无效");
        }
    }

    public void recordTest(boolean successful, String message, LocalDateTime testedAt) {
        repository.recordTest(successful, message, testedAt);
    }

    private AiProviderView toView(ProviderRow row) {
        return new AiProviderView(
                nullToEmpty(row.providerName()),
                nullToEmpty(row.baseUrl()),
                hasText(row.apiKeyCiphertext()),
                nullToEmpty(row.model()),
                row.temperature() == null ? DEFAULT_TEMPERATURE : row.temperature(),
                row.timeoutSeconds(),
                row.lastTestStatus(),
                row.lastTestMessage(),
                row.lastTestAt());
    }

    private static void requireExplicitKeyForNewEndpoint(
            Optional<ProviderRow> previous, String nextUrl, String suppliedKey, Boolean clearKey) {
        if (previous.isPresent()
                && hasText(previous.get().apiKeyCiphertext())
                && !normalizeAndValidateBaseUrl(previous.get().baseUrl()).equals(nextUrl)
                && !hasText(suppliedKey)
                && !Boolean.TRUE.equals(clearKey)) {
            throw badRequest("修改服务地址时请重新填写或明确清除 API Key");
        }
    }

    private String selectCiphertext(AiProviderSaveRequest request, Optional<ProviderRow> previous) {
        if (Boolean.TRUE.equals(request.clearApiKey())) {
            return null;
        }
        if (hasText(request.apiKey())) {
            return encryptionService.encrypt(request.apiKey().trim());
        }
        return previous.map(ProviderRow::apiKeyCiphertext).orElse(null);
    }

    private String decryptIfPresent(String ciphertext) {
        return hasText(ciphertext) ? encryptionService.decrypt(ciphertext) : null;
    }

    private static String normalizeAndValidateBaseUrl(String suppliedValue) {
        String candidate = trimTrailingSlashes(trimToEmpty(suppliedValue));
        if (candidate.isEmpty()) {
            throw badRequest("AI 服务地址不能为空");
        }

        final URI uri;
        try {
            uri = new URI(candidate);
        } catch (URISyntaxException exception) {
            throw badRequest("AI 服务地址格式不正确");
        }

        String scheme = uri.getScheme();
        boolean http = scheme != null
                && ("http".equals(scheme.toLowerCase(Locale.ROOT)) || "https".equals(scheme.toLowerCase(Locale.ROOT)));
        if (!http
                || uri.getHost() == null
                || uri.getHost().isBlank()
                || uri.getUserInfo() != null
                || uri.getQuery() != null
                || uri.getFragment() != null) {
            throw badRequest("AI 服务地址必须是安全有效的 HTTP(S) 地址");
        }
        return candidate;
    }

    private static String trimTrailingSlashes(String value) {
        int end = value.length();
        while (end > 0 && value.charAt(end - 1) == '/') {
            end--;
        }
        return value.substring(0, end);
    }

    private static String trimToEmpty(String value) {
        return value == null ? "" : value.trim();
    }

    private static String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    private static boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private static ApiException badRequest(String message) {
        return new ApiException(BAD_REQUEST, message, "api.common.badRequest");
    }
}
