package com.kaiwu.module.gitlab;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.gitlab.GitlabConfigRepository.GitlabConfigRow;
import com.kaiwu.module.gitlab.dto.GitlabConfigSaveRequest;
import com.kaiwu.module.gitlab.vo.GitlabConfigView;
import com.kaiwu.module.metadata.ConfigEncryptionService;
import java.net.URI;
import java.time.LocalDateTime;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class GitlabConfigService {

    private final GitlabConfigRepository repository;
    private final ConfigEncryptionService encryptionService;

    public GitlabConfigService(GitlabConfigRepository repository, ConfigEncryptionService encryptionService) {
        this.repository = repository;
        this.encryptionService = encryptionService;
    }

    /** 管理页面读取的当前配置；令牌以掩码返回，未配置时返回空壳而不是 null。 */
    public GitlabConfigView current() {
        return repository
                .current()
                .map(this::view)
                .orElseGet(() -> new GitlabConfigView("", "", false, false, null, null, null));
    }

    /** 保存配置；提交掩码值表示「不修改令牌」，避免每次编辑都要重填。 */
    public void save(GitlabConfigSaveRequest request) {
        GitlabConfigRow existing = repository.current().orElse(null);
        String ciphertext = existing == null ? null : existing.tokenCiphertext();
        if (Boolean.TRUE.equals(request.clearToken())) {
            ciphertext = null;
        } else if (StringUtils.hasText(request.token())) {
            ciphertext = encryptionService.encrypt(request.token().trim());
        }
        boolean enabled = request.enabled() == null || request.enabled();
        if (enabled && !StringUtils.hasText(ciphertext)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "启用 GitLab 前必须配置 API Token", "api.common.badRequest");
        }
        repository.save(new GitlabConfigRow(
                validateBaseUrl(request.baseUrl()),
                ciphertext,
                normalize(request.defaultGroupId()),
                enabled,
                existing == null ? null : existing.lastTestStatus(),
                existing == null ? null : existing.lastTestMessage(),
                existing == null ? null : existing.lastTestAt()));
    }

    /** 取可用的运行期配置；未配置或已停用时抛出，让调用方在动手前就失败。 */
    public RuntimeConfig requireEnabled() {
        GitlabConfigRow row = repository
                .current()
                .filter(GitlabConfigRow::enabled)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.SERVICE_UNAVAILABLE, "GitLab 尚未配置或未启用", "api.common.serviceUnavailable"));
        if (!StringUtils.hasText(row.tokenCiphertext())) {
            throw new ApiException(
                    HttpStatus.SERVICE_UNAVAILABLE, "GitLab API Token 未配置", "api.common.serviceUnavailable");
        }
        return new RuntimeConfig(row.baseUrl(), encryptionService.decrypt(row.tokenCiphertext()), row.defaultGroupId());
    }

    public void recordTest(boolean success, String message, LocalDateTime testedAt) {
        repository.recordTest(success, message, testedAt);
    }

    private GitlabConfigView view(GitlabConfigRow row) {
        return new GitlabConfigView(
                row.baseUrl(),
                row.defaultGroupId(),
                StringUtils.hasText(row.tokenCiphertext()),
                row.enabled(),
                row.lastTestStatus(),
                row.lastTestMessage(),
                row.lastTestAt());
    }

    private String validateBaseUrl(String value) {
        String normalized = value == null ? "" : value.trim().replaceAll("/+$", "");
        try {
            URI uri = URI.create(normalized);
            boolean validScheme = "http".equalsIgnoreCase(uri.getScheme()) || "https".equalsIgnoreCase(uri.getScheme());
            if (!validScheme
                    || !StringUtils.hasText(uri.getHost())
                    || uri.getUserInfo() != null
                    || uri.getQuery() != null
                    || uri.getFragment() != null) {
                throw new IllegalArgumentException();
            }
            return normalized;
        } catch (IllegalArgumentException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "GitLab 地址必须是无凭据、无 query/fragment 的有效 HTTP(S) URL",
                    "api.common.badRequest");
        }
    }

    private static String normalize(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }

    public record RuntimeConfig(String baseUrl, String token, String defaultGroupId) {}
}
