package com.kaiwu.module.i18n;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.LocaleCode;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.audit.AuditService;
import com.kaiwu.module.i18n.I18nRepository.MessageRow;
import com.kaiwu.module.i18n.dto.I18nMessageSaveRequest;
import com.kaiwu.module.i18n.vo.I18nMessageView;
import com.kaiwu.starter.KaiwuContext;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.concurrent.atomic.AtomicLong;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

/** 国际化资源的写入规则、乐观锁和审计。 */
@Component
final class I18nMessageService {

    private static final Pattern PLACEHOLDER = Pattern.compile("\\{([A-Za-z][A-Za-z0-9_]*)}");
    private static final Set<String> PUBLIC_KEYS = Set.of(
            "common.language",
            "common.language.zhCN",
            "common.language.enUS",
            "common.language.updated",
            "common.language.updateFailed",
            "client.connectionFailed",
            "client.serviceUnavailable",
            "client.requestFailed",
            "client.loginFailed",
            "client.sessionExpired",
            "client.catalogFailed");
    private static final AtomicLong ID_SEQUENCE = new AtomicLong(System.currentTimeMillis() * 1_000_000L);

    private final I18nRepository repository;
    private final AuditService auditService;
    private final ObjectMapper objectMapper;
    private final I18nCatalogService catalogService;

    I18nMessageService(
            I18nRepository repository,
            AuditService auditService,
            ObjectMapper objectMapper,
            I18nCatalogService catalogService) {
        this.repository = repository;
        this.auditService = auditService;
        this.objectMapper = objectMapper;
        this.catalogService = catalogService;
    }

    List<I18nMessageView> messages() {
        return repository.messages(false, false).stream()
                .map(I18nMessageService::view)
                .toList();
    }

    I18nMessageView save(I18nMessageSaveRequest request, KaiwuContext actor, RequestMetadata metadata) {
        String id = StringUtils.hasText(request.id()) ? request.id().trim() : nextId();
        MessageRow existing = repository.message(id).orElse(null);
        validateIdentity(request, existing);
        Map<String, String> translations =
                validateTranslations(request.defaultText().trim(), request.translationsJson());
        validatePublicScope(request);
        if (existing != null && request.version() == null) {
            throw error(HttpStatus.BAD_REQUEST, "更新资源必须携带版本", "api.i18n.versionRequired");
        }
        requireTranslationsForOpenLocales(request, translations);

        MessageRow row = toRow(id, request, translations, existing);
        if (existing == null) {
            repository.insert(row);
        } else if (!repository.update(row, request.version())) {
            throw error(HttpStatus.CONFLICT, "资源已被其他人修改，请刷新后重试", "api.i18n.versionConflict");
        }
        repository.bumpRevision();
        catalogService.invalidate();
        auditService.recordOperation(
                actor, "i18n", "SAVE_I18N_MESSAGE", "/api/i18n/resources", "messageKey=" + row.messageKey(), metadata);
        return view(repository.message(id).orElseThrow());
    }

    void delete(String id, long version, KaiwuContext actor, RequestMetadata metadata) {
        MessageRow row =
                repository.message(id).orElseThrow(() -> error(HttpStatus.NOT_FOUND, "国际化资源不存在", "api.i18n.notFound"));
        if (!repository.delete(id, version)) {
            throw error(HttpStatus.CONFLICT, "资源已被其他人修改，请刷新后重试", "api.i18n.versionConflict");
        }
        repository.bumpRevision();
        catalogService.invalidate();
        auditService.recordOperation(
                actor,
                "i18n",
                "DELETE_I18N_MESSAGE",
                "/api/i18n/resources/" + id,
                "messageKey=" + row.messageKey(),
                metadata);
    }

    private void validateIdentity(I18nMessageSaveRequest request, MessageRow existing) {
        if (StringUtils.hasText(request.id()) && existing == null) {
            throw error(HttpStatus.NOT_FOUND, "国际化资源不存在", "api.i18n.notFound");
        }
        if (existing != null
                && !existing.messageKey().equals(request.messageKey().trim())) {
            throw error(HttpStatus.BAD_REQUEST, "国际化资源 key 创建后不可修改", "api.i18n.keyImmutable");
        }
        if (repository.keyExists(request.messageKey().trim(), request.id())) {
            throw error(HttpStatus.CONFLICT, "国际化资源 key 已存在", "api.i18n.keyExists");
        }
    }

    private void validatePublicScope(I18nMessageSaveRequest request) {
        String key = request.messageKey().trim();
        if (request.publicVisible() && !key.startsWith("login.") && !PUBLIC_KEYS.contains(key)) {
            throw error(HttpStatus.BAD_REQUEST, "该资源不允许匿名公开", "api.i18n.publicKeyInvalid");
        }
    }

    private MessageRow toRow(
            String id, I18nMessageSaveRequest request, Map<String, String> translations, MessageRow existing) {
        return new MessageRow(
                id,
                request.messageKey().trim(),
                request.defaultText().trim(),
                translations.isEmpty() ? null : writeJson(translations),
                request.moduleCode().trim(),
                request.publicVisible(),
                request.requiredResource(),
                request.status(),
                normalize(request.description()),
                existing == null ? 1 : existing.version(),
                existing == null ? null : existing.updatedAt());
    }

    private void requireTranslationsForOpenLocales(I18nMessageSaveRequest request, Map<String, String> translations) {
        if (!Boolean.TRUE.equals(request.requiredResource()) || !"ENABLED".equals(request.status())) return;
        String defaultLocale = catalogService.defaultLocale();
        List<String> missing = catalogService.selectableLocales().stream()
                .filter(locale -> !defaultLocale.equals(locale))
                .filter(locale -> !StringUtils.hasText(translations.get(locale)))
                .toList();
        if (missing.isEmpty()) return;
        String joined = String.join("、", missing);
        throw new ApiException(
                HttpStatus.BAD_REQUEST,
                "覆盖必需资源必须为已开放语言 " + joined + " 提供译文",
                "api.i18n.requiredTranslationMissing",
                Map.of("locales", String.join(", ", missing)));
    }

    private Map<String, String> validateTranslations(String defaultText, String json) {
        rejectHtml(defaultText);
        if (!StringUtils.hasText(json)) return Map.of();
        try {
            Map<String, Object> raw = objectMapper.readValue(json, new TypeReference<Map<String, Object>>() {});
            Set<String> enabled = repository.enabledLocales().stream()
                    .filter(LocaleCode::isValid)
                    .collect(java.util.stream.Collectors.toCollection(LinkedHashSet::new));
            return validatedTranslations(defaultText, raw, enabled);
        } catch (ApiException exception) {
            throw exception;
        } catch (Exception exception) {
            throw error(HttpStatus.BAD_REQUEST, "多语言译文必须是合法 JSON 对象", "api.i18n.jsonInvalid");
        }
    }

    private Map<String, String> validatedTranslations(
            String defaultText, Map<String, Object> raw, Set<String> enabled) {
        Set<String> expectedPlaceholders = placeholders(defaultText);
        Map<String, String> result = new LinkedHashMap<>();
        for (Map.Entry<String, Object> entry : raw.entrySet()) {
            if (catalogService.defaultLocale().equals(entry.getKey()) || !enabled.contains(entry.getKey())) {
                throw error(HttpStatus.BAD_REQUEST, "包含未启用或重复默认语言", "api.i18n.localeInvalid");
            }
            if (!(entry.getValue() instanceof String text) || !StringUtils.hasText(text)) {
                throw error(HttpStatus.BAD_REQUEST, "译文必须是非空文本", "api.i18n.translationInvalid");
            }
            rejectHtml(text);
            if (!expectedPlaceholders.equals(placeholders(text))) {
                throw error(HttpStatus.BAD_REQUEST, "译文占位符与默认文案不一致", "api.i18n.placeholderMismatch");
            }
            result.put(entry.getKey(), text.trim());
        }
        return result;
    }

    private static Set<String> placeholders(String text) {
        Set<String> result = new TreeSet<>();
        Matcher matcher = PLACEHOLDER.matcher(text);
        while (matcher.find()) result.add(matcher.group(1));
        return result;
    }

    private static void rejectHtml(String text) {
        if (text.indexOf('<') >= 0 || text.indexOf('>') >= 0) {
            throw error(HttpStatus.BAD_REQUEST, "国际化资源只允许纯文本", "api.i18n.htmlForbidden");
        }
    }

    private String writeJson(Map<String, String> value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (Exception exception) {
            throw error(HttpStatus.BAD_REQUEST, "无法序列化译文", "api.i18n.jsonInvalid");
        }
    }

    private static I18nMessageView view(MessageRow row) {
        return new I18nMessageView(
                row.id(),
                row.messageKey(),
                row.defaultText(),
                row.translationsJson(),
                row.moduleCode(),
                row.publicVisible(),
                row.requiredResource(),
                row.status(),
                row.description(),
                row.version(),
                row.updatedAt());
    }

    private static ApiException error(HttpStatus status, String message, String key) {
        return new ApiException(status, message, key);
    }

    private static String normalize(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }

    private static String nextId() {
        return String.valueOf(ID_SEQUENCE.incrementAndGet());
    }
}
