package com.kaiwu.module.ai;

import static org.springframework.http.HttpStatus.BAD_REQUEST;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.ai.AiProviderRepository.ProviderRow;
import com.kaiwu.module.ai.dto.AiProviderSaveRequest;
import com.kaiwu.module.ai.vo.AiProviderView;
import com.kaiwu.module.metadata.ConfigEncryptionService;
import java.math.BigDecimal;
import java.net.URI;
import java.net.URISyntaxException;
import java.time.LocalDateTime;
import java.util.Locale;
import java.util.Optional;
import org.springframework.stereotype.Service;

/**
 * Applies validation, defaults, and secret handling around the provider config.
 */
@Service
public final class AiProviderService {

    private static final BigDecimal DEFAULT_TEMPERATURE = new BigDecimal("0.2");
    private static final int DEFAULT_TIMEOUT_SECONDS = 60;

    private final AiProviderRepository repository;
    private final ConfigEncryptionService encryptionService;

    public AiProviderService(AiProviderRepository repository, ConfigEncryptionService encryptionService) {
        this.repository = repository;
        this.encryptionService = encryptionService;
    }

    /** 管理页面读取的当前配置；API Key 以掩码返回，不外发明文。 */
    public AiProviderView current() {
        return repository
                .current()
                .map(this::toView)
                .orElseGet(() -> new AiProviderView(
                        "", "", false, "", DEFAULT_TEMPERATURE, DEFAULT_TIMEOUT_SECONDS, false, null, null, null));
    }

    /** 保存配置；提交掩码值表示「不修改 Key」，避免每次编辑都要重填密钥。 */
    public void save(AiProviderSaveRequest request) {
        if (request == null) {
            throw badRequest("AI 服务配置不能为空");
        }

        Optional<ProviderRow> previous = repository.current();
        String apiKeyCiphertext = selectCiphertext(request, previous);
        String baseUrl = normalizeAndValidateBaseUrl(request.baseUrl());

        repository.save(new ProviderRow(
                trimToEmpty(request.providerName()),
                baseUrl,
                apiKeyCiphertext,
                trimToEmpty(request.model()),
                request.temperature() == null ? DEFAULT_TEMPERATURE : request.temperature(),
                request.timeoutSeconds() == null ? DEFAULT_TIMEOUT_SECONDS : request.timeoutSeconds(),
                request.enabled() == null || request.enabled(),
                previous.map(ProviderRow::lastTestStatus).orElse(null),
                previous.map(ProviderRow::lastTestMessage).orElse(null),
                previous.map(ProviderRow::lastTestAt).orElse(null)));
    }

    /** 供生成流程使用的运行期配置；未启用或未配置时返回空，由调用方决定如何降级。 */
    public Optional<RuntimeConfig> effective() {
        return repository
                .current()
                .filter(ProviderRow::enabled)
                .map(row -> new RuntimeConfig(
                        row.providerName(),
                        normalizeAndValidateBaseUrl(row.baseUrl()),
                        decryptIfPresent(row.apiKeyCiphertext()),
                        row.model(),
                        row.temperature() == null ? DEFAULT_TEMPERATURE : row.temperature(),
                        row.timeoutSeconds()));
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
                row.enabled(),
                row.lastTestStatus(),
                row.lastTestMessage(),
                row.lastTestAt());
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

    public record RuntimeConfig(
            String providerName,
            String baseUrl,
            String apiKey,
            String model,
            BigDecimal temperature,
            int timeoutSeconds) {}
}
