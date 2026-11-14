package com.kaiwu.module.configuration.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.LocaleCode;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.repository.MetadataRepository;
import com.kaiwu.module.configuration.repository.MetadataRepository.ConfigRow;
import com.kaiwu.module.configuration.repository.MetadataRepository.DictItemRow;
import com.kaiwu.module.configuration.repository.MetadataRepository.DictTypeRow;
import com.kaiwu.module.configuration.service.ConfigEncryptionService;
import com.kaiwu.module.configuration.service.I18nService;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.metadata.dto.ConfigSaveRequest;
import com.kaiwu.module.metadata.dto.DictItemSaveRequest;
import com.kaiwu.module.metadata.dto.DictTypeSaveRequest;
import com.kaiwu.module.metadata.vo.*;
import com.kaiwu.module.operation.model.FieldChange;
import com.kaiwu.module.operation.service.AuditService;
import com.kaiwu.module.project.repository.ProjectRepository;
import com.kaiwu.starter.KaiwuContext;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import tools.jackson.databind.ObjectMapper;

@Service("metadataService")
public class MetadataServiceImpl implements MetadataService {

    private static final String LOCALE_DICT_CODE = "platform.locale";
    private static final AtomicLong ID_SEQUENCE = new AtomicLong(System.currentTimeMillis() * 1_000_000L);

    private final MetadataRepository repository;
    private final ProjectRepository projectRepository;
    private final ConfigEncryptionService encryptionService;
    private final AuditService auditService;
    private final ObjectMapper objectMapper;
    private final I18nService i18nService;
    private final Clock clock;

    public MetadataServiceImpl(
            MetadataRepository repository,
            ProjectRepository projectRepository,
            ConfigEncryptionService encryptionService,
            AuditService auditService,
            ObjectMapper objectMapper,
            I18nService i18nService,
            Clock clock) {
        this.repository = repository;
        this.projectRepository = projectRepository;
        this.encryptionService = encryptionService;
        this.auditService = auditService;
        this.objectMapper = objectMapper;
        this.i18nService = i18nService;
        this.clock = clock;
    }

    public List<ConfigView> configs(String scopeId) {
        requireScope(scopeId);
        return repository.configs(scopeId, false).stream()
                .map(this::toConfigView)
                .toList();
    }

    private record UiPreference(int fallback, int min, int max) {}

    private static final Map<String, UiPreference> UI_PREFERENCES = Map.of(
            "platform.notification.poll_seconds", new UiPreference(60, 15, 600),
            "platform.factory.poll_seconds", new UiPreference(3, 2, 60),
            "platform.home.poll_seconds", new UiPreference(5, 2, 60));

    /** 仅返回明确列出的非敏感参数，异常存量值使用安全默认值。 */
    public Map<String, Integer> platformUiPreferences() {
        Map<String, Integer> result = new LinkedHashMap<>();
        UI_PREFERENCES.forEach((key, spec) -> result.put(key, spec.fallback()));
        repository.configs(GLOBAL_SCOPE, true).stream()
                .filter(row -> !row.secret() && UI_PREFERENCES.containsKey(row.configKey()))
                .forEach(row -> {
                    UiPreference spec = UI_PREFERENCES.get(row.configKey());
                    try {
                        int value = Integer.parseInt(row.configValue());
                        if (value >= spec.min() && value <= spec.max()) result.put(row.configKey(), value);
                    } catch (NumberFormatException ignored) {
                        // 错误存量不影响页面，使用默认值。
                    }
                });
        return result;
    }

    private void validateUiPreference(String scopeId, ConfigSaveRequest request, String value) {
        String key = request.configKey().trim();
        if ("common.table.page_size".equals(key)) {
            try {
                int size = Integer.parseInt(value);
                if (!request.secret()
                        && "NUMBER".equals(request.valueType())
                        && !StringUtils.hasText(request.valueI18nKey())
                        && size >= 5
                        && size <= 200) return;
            } catch (NumberFormatException ignored) {
                // 参数格式非法，返回清晰的范围提示。
            }
            throw new ApiException(HttpStatus.BAD_REQUEST, "每页条数需为 5–200 的非敏感整数且不可引用国际化", "api.common.badRequest");
        }
        UiPreference spec = UI_PREFERENCES.get(key);
        if (spec == null) return;
        try {
            int parsed = Integer.parseInt(value);
            if (GLOBAL_SCOPE.equals(scopeId)
                    && !request.secret()
                    && "NUMBER".equals(request.valueType())
                    && !StringUtils.hasText(request.valueI18nKey())
                    && parsed >= spec.min()
                    && parsed <= spec.max()) return;
        } catch (NumberFormatException ignored) {
            // 统一返回可操作的约束说明。
        }
        throw new ApiException(
                HttpStatus.BAD_REQUEST,
                "该参数仅支持全局非敏感整数且不可引用国际化，范围 " + spec.min() + "–" + spec.max() + " 秒",
                "api.common.badRequest");
    }

    /** 新增或编辑参数配置；键在作用域内唯一，敏感值落库前加密。 */
    @Transactional
    public ConfigView saveConfig(
            String scopeId, ConfigSaveRequest request, KaiwuContext actor, RequestMetadata metadata) {
        requireScope(scopeId);
        ConfigRow existing = existingConfig(scopeId, request.id());
        if (repository.configKeyExists(scopeId, request.configKey().trim(), request.id())) {
            throw new ApiException(HttpStatus.CONFLICT, "当前范围已存在该配置键", "api.common.conflict");
        }
        boolean preserveSecret = existing != null
                && existing.secret()
                && request.secret()
                && (!StringUtils.hasText(request.configValue()) || MASKED_VALUE.equals(request.configValue()));
        if (existing != null
                && existing.secret()
                && !request.secret()
                && (!StringUtils.hasText(request.configValue()) || MASKED_VALUE.equals(request.configValue()))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "取消敏感配置时必须重新填写配置值", "api.common.badRequest");
        }
        String value = preserveSecret
                ? existing.configValue()
                : Objects.toString(request.configValue(), "").trim();
        if (!preserveSecret) {
            validateValue(request.valueType(), value);
            validateUiPreference(scopeId, request, value);
            if (request.secret()) {
                value = encryptionService.encrypt(value);
            }
        }
        String valueI18nKey = normalize(request.valueI18nKey());
        requireExistingMessageKey(scopeId, valueI18nKey);
        String id = existing == null ? nextId() : existing.id();
        ConfigRow row = new ConfigRow(
                id,
                scopeId,
                request.configKey().trim(),
                value,
                valueI18nKey,
                request.valueType(),
                request.secret(),
                request.status(),
                normalize(request.description()),
                request.sortNo(),
                existing == null ? LocalDateTime.now(clock) : existing.createdAt(),
                LocalDateTime.now(clock));
        repository.saveConfig(row, existing == null);
        auditService.recordOperationWithDiff(
                actor,
                "metadata",
                "SAVE_CONFIG",
                "/api/metadata/configs",
                "config",
                id,
                configChanges(existing, row),
                metadata);
        return toConfigView(repository.config(id).orElseThrow());
    }

    /** 删除参数配置；删除是不可逆的，调用方需自行确认没有运行期依赖。 */
    @Transactional
    public void deleteConfig(String scopeId, String id, KaiwuContext actor, RequestMetadata metadata) {
        ConfigRow row = repository
                .config(id)
                .filter(item -> item.scopeId().equals(scopeId))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "配置不存在", "api.common.notFound"));
        repository.deleteConfig(row.id());
        auditService.recordOperation(
                actor,
                "metadata",
                "DELETE_CONFIG",
                "/api/metadata/configs/" + id,
                "scopeId=" + scopeId + ",configId=" + id,
                metadata);
    }

    /** Snapshot never contains the configuration value, including encrypted secrets. */
    public ConfigDeleteSnapshot previewGlobalConfigDeletion(String id) {
        ConfigRow row = repository
                .config(id)
                .filter(item -> GLOBAL_SCOPE.equals(item.scopeId()))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "配置不存在", "api.common.notFound"));
        return new ConfigDeleteSnapshot(
                row.configKey(), row.valueType(), row.secret(), row.status(), configFingerprint(row));
    }

    @Transactional
    public void deleteGlobalConfigForAgent(
            String id, ConfigDeleteSnapshot expected, KaiwuContext actor, RequestMetadata metadata) {
        if (expected == null || expected.fingerprint() == null)
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        ConfigRow row = repository
                .configForUpdate(id)
                .filter(item -> GLOBAL_SCOPE.equals(item.scopeId()))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "配置不存在", "api.common.notFound"));
        if (!Objects.equals(expected.configKey(), row.configKey())
                || !Objects.equals(expected.valueType(), row.valueType())
                || expected.secret() != row.secret()
                || !Objects.equals(expected.status(), row.status())
                || !Objects.equals(expected.fingerprint(), configFingerprint(row)))
            throw new ApiException(HttpStatus.CONFLICT, "配置已变化，请重新预览", "api.common.conflict");
        repository.deleteConfig(id);
        auditService.recordOperation(
                actor,
                "metadata",
                "DELETE_CONFIG",
                "/api/metadata/configs/" + id,
                "scopeId=0,configId=" + id,
                metadata);
    }

    private static String configFingerprint(ConfigRow row) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            for (Object field : new Object[] {
                row.id(),
                row.scopeId(),
                row.configKey(),
                row.configValue(),
                row.valueI18nKey(),
                row.valueType(),
                row.secret(),
                row.status(),
                row.description(),
                row.sortNo(),
                row.createdAt(),
                row.updatedAt()
            }) {
                String value = field == null ? null : field.toString();
                String length = value == null ? "-1:" : value.length() + ":";
                digest.update(length.getBytes(StandardCharsets.UTF_8));
                if (value != null) digest.update(value.getBytes(StandardCharsets.UTF_8));
            }
            return HexFormat.of().formatHex(digest.digest());
        } catch (NoSuchAlgorithmException missing) {
            throw new IllegalStateException("SHA-256 unavailable", missing);
        }
    }

    /** 浏览器侧：语言取用户偏好，已登录因此不是匿名解析。 */
    public List<EffectiveConfigView> effectiveConfigs(String projectId, String userId, String language) {
        requireActiveMember(projectId, userId);
        return effectiveConfigsOfProject(projectId, language, false);
    }

    /**
     * 项目生效配置：global 作底、项目级覆盖。
     *
     * <p>不做成员校验，只能由已经确认过项目归属的调用方使用——浏览器侧走
     * {@link #effectiveConfigs(String, String)}，业务服务侧由项目服务凭据先验明项目。
     * 无论哪条路径都过滤 secret 配置：密钥不通过配置读取接口外发。</p>
     */
    public List<EffectiveConfigView> effectiveConfigsOfProject(String projectId) {
        return effectiveConfigsOfProject(projectId, null, false);
    }

    /**
     * @param language  请求语言；引用了资源的配置按它解析后下发
     * @param anonymous 未登录调用必须传 true，此时只解析 public_visible 资源
     */
    public List<EffectiveConfigView> effectiveConfigsOfProject(String projectId, String language, boolean anonymous) {
        Map<String, ConfigRow> merged = new LinkedHashMap<>();
        repository.configs(GLOBAL_SCOPE, true).stream()
                .filter(item -> !item.secret())
                .forEach(item -> merged.put(item.configKey(), item));
        repository.configs(projectId, true).stream()
                .filter(item -> !item.secret())
                .forEach(item -> merged.put(item.configKey(), item));
        // 下发已解析文本而不是 key：Starter 读的是业务进程内的内存快照，够不到平台目录，
        // 下发 key 会让业务后端拿到一个自己翻译不了的值。
        I18nService.LocalizedText localizedText = i18nService.resolver(projectId, language, anonymous);
        return merged.values().stream()
                .map(item -> new EffectiveConfigView(
                        item.configKey(),
                        localizedText.of(item.valueI18nKey(), item.configValue()),
                        item.valueType(),
                        item.description(),
                        item.scopeId()))
                .toList();
    }

    public List<DictTypeView> dictTypes(String scopeId) {
        requireScope(scopeId);
        return repository.dictTypes(scopeId, false).stream()
                .map(this::toTypeView)
                .toList();
    }

    /** 新增或编辑字典类型；编码在作用域内唯一。 */
    @Transactional
    public DictTypeView saveDictType(
            String scopeId, DictTypeSaveRequest request, KaiwuContext actor, RequestMetadata metadata) {
        requireScope(scopeId);
        DictTypeRow existing = existingType(scopeId, request.id());
        if (repository.dictCodeExists(scopeId, request.dictCode().trim(), request.id())) {
            throw new ApiException(HttpStatus.CONFLICT, "当前范围已存在该字典编码", "api.common.conflict");
        }
        String dictNameKey = normalize(request.dictNameKey());
        requireExistingMessageKey(scopeId, dictNameKey);
        String id = existing == null ? nextId() : existing.id();
        // 新建排到末尾；编辑保留既有顺序——排序由拖拽单独维护，表单里没有这个字段。
        int sortNo = existing == null
                ? repository.maxDictTypeSortNo(scopeId) + MetadataRepository.SORT_STEP
                : existing.sortNo();
        DictTypeRow row = new DictTypeRow(
                id,
                scopeId,
                request.dictCode().trim(),
                request.dictName().trim(),
                dictNameKey,
                !GLOBAL_SCOPE.equals(scopeId) && request.inheritGlobal(),
                sortNo,
                request.status(),
                normalize(request.description()),
                existing == null ? LocalDateTime.now(clock) : existing.createdAt(),
                LocalDateTime.now(clock));
        repository.saveDictType(row, existing == null);
        auditService.recordOperationWithDiff(
                actor,
                "metadata",
                "SAVE_DICT_TYPE",
                "/api/metadata/dicts",
                "dictType",
                id,
                dictTypeChanges(existing, row),
                metadata);
        return toTypeView(repository.dictType(id).orElseThrow());
    }

    /** Agent rename uses a locked comparison against the server-frozen preview, preserving all other fields. */
    @Transactional
    public DictTypeView renameGlobalDictType(
            String id,
            String newName,
            DictTypeRenameExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        if (newName == null || newName.isBlank() || newName.trim().length() > 128 || expected == null)
            throw new ApiException(HttpStatus.BAD_REQUEST, "字典名称不合法", "api.common.badRequest");
        DictTypeRow existing = repository
                .dictTypeForUpdate(id)
                .filter(row -> GLOBAL_SCOPE.equals(row.scopeId()))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "字典不存在", "api.common.notFound"));
        if (StringUtils.hasText(existing.dictNameKey()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "引用国际化资源的字典需在资源目录修改名称", "api.common.badRequest");
        if (!Objects.equals(existing.dictCode(), expected.dictCode())
                || !Objects.equals(existing.dictName(), expected.dictName())
                || !Objects.equals(existing.status(), expected.status())
                || !Objects.equals(Objects.toString(existing.description(), ""), expected.description()))
            throw new ApiException(HttpStatus.CONFLICT, "字典已变化，请重新预览", "api.common.conflict");
        String name = newName.trim();
        if (name.equals(existing.dictName()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "字典名称没有变化", "api.common.badRequest");
        DictTypeRow changed = new DictTypeRow(
                existing.id(),
                existing.scopeId(),
                existing.dictCode(),
                name,
                existing.dictNameKey(),
                existing.inheritGlobal(),
                existing.sortNo(),
                existing.status(),
                existing.description(),
                existing.createdAt(),
                LocalDateTime.now(clock));
        repository.saveDictType(changed, false);
        auditService.recordOperationWithDiff(
                actor,
                "metadata",
                "SAVE_DICT_TYPE",
                "/api/metadata/dicts",
                "dictType",
                id,
                dictTypeChanges(existing, changed),
                metadata);
        return toTypeView(repository.dictType(id).orElseThrow());
    }

    /** The digest includes the entire type and every child, while only the count is shown in chat. */
    public DictTypeDeleteSnapshot previewGlobalDictTypeDeletion(String id) {
        DictTypeRow type = repository
                .dictType(id)
                .filter(row -> GLOBAL_SCOPE.equals(row.scopeId()))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "字典不存在", "api.common.notFound"));
        List<DictItemRow> items = repository.dictItems(id, false);
        return new DictTypeDeleteSnapshot(
                type.dictCode(), type.dictName(), type.status(), items.size(), dictTypeFingerprint(type, items));
    }

    @Transactional
    public void deleteGlobalDictTypeForAgent(
            String id, DictTypeDeleteSnapshot expected, KaiwuContext actor, RequestMetadata metadata) {
        if (expected == null || expected.fingerprint() == null)
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        DictTypeRow type = repository
                .dictTypeForUpdate(id)
                .filter(row -> GLOBAL_SCOPE.equals(row.scopeId()))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "字典不存在", "api.common.notFound"));
        List<DictItemRow> items = repository.dictItemsForUpdate(id);
        if (!Objects.equals(expected.dictCode(), type.dictCode())
                || !Objects.equals(expected.dictName(), type.dictName())
                || !Objects.equals(expected.status(), type.status())
                || expected.itemCount() != items.size()
                || !Objects.equals(expected.fingerprint(), dictTypeFingerprint(type, items)))
            throw new ApiException(HttpStatus.CONFLICT, "字典已变化，请重新预览", "api.common.conflict");
        repository.deleteDictType(id);
        auditService.recordOperation(
                actor,
                "metadata",
                "DELETE_DICT_TYPE",
                "/api/metadata/dicts/" + id,
                "scopeId=0,dictTypeId=" + id + ",itemCount=" + items.size(),
                metadata);
    }

    private static String dictTypeFingerprint(DictTypeRow type, List<DictItemRow> items) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            updateDigest(digest, type.toString());
            items.stream()
                    .sorted(Comparator.comparing(DictItemRow::id))
                    .forEach(item -> updateDigest(digest, item.toString()));
            return HexFormat.of().formatHex(digest.digest());
        } catch (NoSuchAlgorithmException missing) {
            throw new IllegalStateException("SHA-256 unavailable", missing);
        }
    }

    private static void updateDigest(MessageDigest digest, String value) {
        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        digest.update(Integer.toString(bytes.length).getBytes(StandardCharsets.US_ASCII));
        digest.update((byte) ':');
        digest.update(bytes);
    }

    /** 删除字典类型，连同其下全部字典项——留下孤儿字典项会让页面显示空标签。 */
    @Transactional
    public void deleteDictType(String scopeId, String id, KaiwuContext actor, RequestMetadata metadata) {
        requireType(scopeId, id);
        repository.deleteDictType(id);
        auditService.recordOperation(
                actor,
                "metadata",
                "DELETE_DICT_TYPE",
                "/api/metadata/dicts/" + id,
                "scopeId=" + scopeId + ",dictTypeId=" + id,
                metadata);
    }

    /**
     * 按拖拽结果重排某作用域下的字典类型。
     *
     * @param ids 排序后的完整 ID 列表；必须与库中现有集合完全一致，否则整批拒绝
     */
    @Transactional
    public void sortDictTypes(String scopeId, List<String> ids, KaiwuContext actor, RequestMetadata metadata) {
        requireScope(scopeId);
        List<String> ordered = requireCompleteOrder(
                repository.dictTypes(scopeId, false).stream()
                        .map(DictTypeRow::id)
                        .toList(),
                ids);
        repository.resortDictTypes(ordered);
        auditService.recordOperation(
                actor,
                "metadata",
                "SORT_DICT_TYPES",
                "/api/metadata/dicts/sort",
                // 只记条数不记 ID 列表：detail 是 VARCHAR(1000)，19 位 ID 拼几十条就会被截断，
                // 截断后的半截列表比不记更容易误导排查。
                "scopeId=" + scopeId + ",count=" + ordered.size(),
                metadata);
    }

    /** 按拖拽结果重排某字典下的字典项；集合校验语义同 {@link #sortDictTypes}。 */
    @Transactional
    public void sortDictItems(
            String scopeId, String typeId, List<String> ids, KaiwuContext actor, RequestMetadata metadata) {
        requireType(scopeId, typeId);
        List<String> ordered = requireCompleteOrder(
                repository.dictItems(typeId, false).stream()
                        .map(DictItemRow::id)
                        .toList(),
                ids);
        repository.resortDictItems(ordered);
        auditService.recordOperation(
                actor,
                "metadata",
                "SORT_DICT_ITEMS",
                "/api/metadata/dicts/" + typeId + "/items/sort",
                "scopeId=" + scopeId + ",dictTypeId=" + typeId + ",count=" + ordered.size(),
                metadata);
    }

    /**
     * 校验提交的顺序覆盖且只覆盖现有集合。
     *
     * <p>提交的列表和库里对不上，说明前端持有的是过期数据（别人刚删了或加了一条）。
     * 此时按提交值写下去，未被提及的行会保留旧 sort_no 而混进任意位置——用户看到的结果
     * 既不是拖成的样子，也没有任何报错。宁可整批拒绝，让前端刷新后重来。</p>
     */
    private static List<String> requireCompleteOrder(List<String> current, List<String> submitted) {
        List<String> ordered = submitted.stream()
                .filter(StringUtils::hasText)
                .map(String::trim)
                .toList();
        if (new HashSet<>(ordered).size() != ordered.size() || !new HashSet<>(ordered).equals(new HashSet<>(current))) {
            throw new ApiException(HttpStatus.CONFLICT, "排序列表与当前数据不一致，请刷新后重试", "api.common.conflict");
        }
        return ordered;
    }

    public List<DictItemView> dictItems(String scopeId, String typeId) {
        requireType(scopeId, typeId);
        return repository.dictItems(typeId, false).stream()
                .map(this::toItemView)
                .toList();
    }

    /**
     * 新增或编辑字典项。
     *
     * <p>多语言只走引用国际化资源（ADR 0015）：引用的 key 必须已存在，写入时就校验，
     * 留到展示时才发现意味着保存已成功、界面却显示不出文案。</p>
     */
    @Transactional
    public DictItemView saveDictItem(
            String scopeId, String typeId, DictItemSaveRequest request, KaiwuContext actor, RequestMetadata metadata) {
        DictTypeRow type = requireType(scopeId, typeId);
        DictItemRow existing = existingItem(typeId, request.id());
        if (repository.dictValueExists(typeId, request.itemValue().trim(), request.id())) {
            throw new ApiException(HttpStatus.CONFLICT, "字典值已存在", "api.common.conflict");
        }
        validateJson(request.extraJson(), "扩展 JSON");
        if (GLOBAL_SCOPE.equals(scopeId)
                && LOCALE_DICT_CODE.equals(type.dictCode())
                && !LocaleCode.isValid(request.itemValue().trim())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "语言代码必须是规范 BCP 47 标签", "api.locale.codeInvalid");
        }
        String labelI18nKey = normalize(request.labelI18nKey());
        requireExistingMessageKey(scopeId, labelI18nKey);
        String id = existing == null ? nextId() : existing.id();
        DictItemRow row = new DictItemRow(
                id,
                typeId,
                request.itemLabel().trim(),
                request.itemValue().trim(),
                request.sortNo(),
                request.defaultItem(),
                normalize(request.color()),
                normalize(request.extraJson()),
                request.status(),
                // ADR 0015：内联多语言列已退役，一律写 null；多语言只走引用资源。
                null,
                labelI18nKey);
        repository.saveDictItem(row, existing == null);
        auditService.recordOperationWithDiff(
                actor,
                "metadata",
                "SAVE_DICT_ITEM",
                "/api/metadata/dicts/" + typeId + "/items",
                "dictItem",
                id,
                dictItemChanges(existing, row),
                metadata);
        return toItemView(repository.dictItem(id).orElseThrow());
    }

    /** Rename one global item after checking the state frozen in the Agent preview. */
    @Transactional
    public DictItemView renameGlobalDictItem(
            String typeId,
            String itemId,
            String newLabel,
            DictItemRenameExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        if (newLabel == null || newLabel.isBlank() || newLabel.trim().length() > 128 || expected == null)
            throw new ApiException(HttpStatus.BAD_REQUEST, "字典项标签不合法", "api.common.badRequest");
        requireType(GLOBAL_SCOPE, typeId);
        DictItemRow existing = repository
                .dictItemForUpdate(itemId)
                .filter(row -> typeId.equals(row.dictTypeId()))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "字典项不存在", "api.common.notFound"));
        if (StringUtils.hasText(existing.labelI18nKey()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "引用国际化资源的字典项需在资源目录修改标签", "api.common.badRequest");
        if (!Objects.equals(existing.itemLabel(), expected.itemLabel())
                || !Objects.equals(existing.itemValue(), expected.itemValue())
                || !Objects.equals(existing.status(), expected.status()))
            throw new ApiException(HttpStatus.CONFLICT, "字典项已变化，请重新预览", "api.common.conflict");
        String label = newLabel.trim();
        if (label.equals(existing.itemLabel()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "字典项标签没有变化", "api.common.badRequest");
        DictItemRow changed = new DictItemRow(
                existing.id(),
                existing.dictTypeId(),
                label,
                existing.itemValue(),
                existing.sortNo(),
                existing.defaultItem(),
                existing.color(),
                existing.extraJson(),
                existing.status(),
                existing.labelI18n(),
                existing.labelI18nKey());
        repository.saveDictItem(changed, false);
        auditService.recordOperationWithDiff(
                actor,
                "metadata",
                "SAVE_DICT_ITEM",
                "/api/metadata/dicts/" + typeId + "/items",
                "dictItem",
                itemId,
                dictItemChanges(existing, changed),
                metadata);
        return toItemView(repository.dictItem(itemId).orElseThrow());
    }

    /** Freeze the visible identity and status that the operator is confirming. */
    public DictItemDeleteSnapshot previewGlobalDictItemDeletion(String typeId, String itemId) {
        requireType(GLOBAL_SCOPE, typeId);
        DictItemRow row = existingItem(typeId, itemId);
        return new DictItemDeleteSnapshot(row.itemLabel(), row.itemValue(), row.status());
    }

    @Transactional
    public void deleteGlobalDictItemForAgent(
            String typeId,
            String itemId,
            DictItemDeleteSnapshot expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        if (expected == null) throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        requireType(GLOBAL_SCOPE, typeId);
        DictItemRow row = repository
                .dictItemForUpdate(itemId)
                .filter(item -> typeId.equals(item.dictTypeId()))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "字典项不存在", "api.common.notFound"));
        if (!Objects.equals(expected.itemLabel(), row.itemLabel())
                || !Objects.equals(expected.itemValue(), row.itemValue())
                || !Objects.equals(expected.status(), row.status()))
            throw new ApiException(HttpStatus.CONFLICT, "字典项已变化，请重新预览", "api.common.conflict");
        repository.deleteDictItem(itemId);
        auditService.recordOperation(
                actor,
                "metadata",
                "DELETE_DICT_ITEM",
                "/api/metadata/dicts/" + typeId + "/items/" + itemId,
                "scopeId=0,dictItemId=" + itemId,
                metadata);
    }

    /** 删除字典项；已被业务数据使用的值删除后，页面按「未知值原样显示」处理。 */
    @Transactional
    public void deleteDictItem(
            String scopeId, String typeId, String itemId, KaiwuContext actor, RequestMetadata metadata) {
        requireType(scopeId, typeId);
        existingItem(typeId, itemId);
        repository.deleteDictItem(itemId);
        auditService.recordOperation(
                actor,
                "metadata",
                "DELETE_DICT_ITEM",
                "/api/metadata/dicts/" + typeId + "/items/" + itemId,
                "scopeId=" + scopeId + ",dictItemId=" + itemId,
                metadata);
    }

    /**
     * 平台级字典查询：仅读取 scope_id=0 的 global 字典，任何登录用户均可访问，
     * 不依赖任何项目上下文；供平台管理前端与业务前端消费。
     *
     * @param language 请求的 Accept-Language；调用方已登录（Starter 拦截器保证），
     *                 因此不按匿名解析（ADR 0014）
     */
    public EffectiveDictView platformDict(String dictCode, String language) {
        DictTypeRow global = repository.enabledDictType(GLOBAL_SCOPE, dictCode).orElse(null);
        if (global == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "字典不存在或未启用", "api.common.notFound");
        }
        String locale = supportedLocale(language);
        return new EffectiveDictView(
                dictCode,
                localizedDictName(global, locale, false),
                global.description(),
                repository.dictItems(global.id(), true).stream()
                        .map(item -> toItemView(item, GLOBAL_SCOPE, locale, false))
                        .toList());
    }

    public EffectiveDictView effectiveDict(String projectId, String dictCode, String userId) {
        return effectiveDict(projectId, dictCode, userId, null);
    }

    /**
     * @param language 请求的 Accept-Language；命中 label_i18n 时返回译文，否则回退录入原文
     */
    public EffectiveDictView effectiveDict(String projectId, String dictCode, String userId, String language) {
        requireActiveMember(projectId, userId);
        DictTypeRow global = repository.enabledDictType(GLOBAL_SCOPE, dictCode).orElse(null);
        DictTypeRow project = repository.enabledDictType(projectId, dictCode).orElse(null);
        if (global == null && project == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "字典不存在或未启用", "api.common.notFound");
        }
        Map<String, DictItemRow> merged = new LinkedHashMap<>();
        if (project == null || project.inheritGlobal()) {
            if (global != null) {
                repository.dictItems(global.id(), true).forEach(item -> merged.put(item.itemValue(), item));
            }
        }
        if (project != null) {
            repository.dictItems(project.id(), true).forEach(item -> merged.put(item.itemValue(), item));
        }
        DictTypeRow effective = project == null ? global : project;
        String locale = supportedLocale(language);
        return new EffectiveDictView(
                dictCode,
                localizedDictName(effective, locale, false),
                effective.description(),
                merged.values().stream()
                        .map(item -> toItemView(item, projectId, locale, false))
                        .toList());
    }

    private ConfigRow existingConfig(String scopeId, String id) {
        if (!StringUtils.hasText(id)) return null;
        return repository
                .config(id)
                .filter(item -> item.scopeId().equals(scopeId))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "配置不存在", "api.common.notFound"));
    }

    private DictTypeRow existingType(String scopeId, String id) {
        if (!StringUtils.hasText(id)) return null;
        return requireType(scopeId, id);
    }

    private DictTypeRow requireType(String scopeId, String id) {
        return repository
                .dictType(id)
                .filter(item -> item.scopeId().equals(scopeId))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "字典不存在", "api.common.notFound"));
    }

    private DictItemRow existingItem(String typeId, String id) {
        if (!StringUtils.hasText(id)) return null;
        return repository
                .dictItem(id)
                .filter(item -> item.dictTypeId().equals(typeId))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "字典项不存在", "api.common.notFound"));
    }

    private void requireScope(String scopeId) {
        if (!StringUtils.hasText(scopeId) || !scopeId.matches("\\d+")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "配置范围不合法", "api.common.badRequest");
        }
        if (!GLOBAL_SCOPE.equals(scopeId)
                && projectRepository.findProject(scopeId).isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "项目不存在", "api.common.notFound");
        }
    }

    private void requireActiveMember(String projectId, String userId) {
        requireScope(projectId);
        if (GLOBAL_SCOPE.equals(projectId) || !projectRepository.activeMemberExists(projectId, userId)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "当前用户不是有效项目成员", "api.common.forbidden");
        }
    }

    private void validateValue(String type, String value) {
        try {
            switch (type) {
                case "NUMBER" -> new BigDecimal(value);
                case "BOOLEAN" -> {
                    if (!"true".equalsIgnoreCase(value) && !"false".equalsIgnoreCase(value)) {
                        throw new IllegalArgumentException();
                    }
                }
                case "JSON" -> objectMapper.readTree(value);
                default -> {}
            }
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "配置值与 " + type + " 类型不匹配", "api.common.badRequest");
        }
    }

    private void validateJson(String json, String label) {
        if (!StringUtils.hasText(json)) return;
        try {
            objectMapper.readTree(json);
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, label + "必须是合法 JSON", "api.common.badRequest");
        }
    }

    /**
     * 引用的 key 必须已存在于目录，写入时就拒绝（ADR 0013 第 6 节）。
     *
     * <p>留到展示时才发现意味着用户已经保存成功、界面却显示不出文案，
     * 而且错误发生地和暴露地相隔很远，很难定位。</p>
     */
    private void requireExistingMessageKey(String scopeId, String key) {
        if (!StringUtils.hasText(key)) return;
        // ADR 0037：项目范围的字典与配置可以引用本项目资源，也可以引用平台资源。
        if (!i18nService.messageKeyExists(scopeId, key)) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST, "国际化资源不存在：" + key, "api.i18n.keyNotFound", Map.of("key", key));
        }
    }

    private ConfigView toConfigView(ConfigRow item) {
        return new ConfigView(
                item.id(),
                item.scopeId(),
                item.configKey(),
                item.secret() ? MASKED_VALUE : item.configValue(),
                item.valueI18nKey(),
                item.valueType(),
                item.secret(),
                item.status(),
                item.description(),
                item.sortNo(),
                item.createdAt(),
                item.updatedAt());
    }

    private DictTypeView toTypeView(DictTypeRow item) {
        return new DictTypeView(
                item.id(),
                item.scopeId(),
                item.dictCode(),
                item.dictName(),
                item.dictNameKey(),
                item.inheritGlobal(),
                item.sortNo(),
                item.status(),
                item.description(),
                item.updatedAt());
    }

    /** 字典名解析：引用的国际化资源 → 录入原文（ADR 0014）。 */
    private String localizedDictName(DictTypeRow type, String locale, boolean anonymous) {
        if (!StringUtils.hasText(type.dictNameKey())) return type.dictName();
        return i18nService.resolver(type.scopeId(), locale, anonymous).of(type.dictNameKey(), type.dictName());
    }

    private DictItemView toItemView(DictItemRow item) {
        return toItemView(item, GLOBAL_SCOPE, null, false);
    }

    /**
     * 按请求语言解析字典项标签（ADR 0014）。
     *
     * <p>解析顺序：引用的国际化资源 key → 内联 label_i18n → 录入原文。
     * 此前这里只有 label_i18n 一层，且消费方 platformDict 从不传 locale，
     * 实际生效的是前端 useDict 里已退役的 dict.{code}.{value} 客户端覆盖——
     * 现在解析顺序与菜单/配置保持一致，服务端一次性给出最终结果。</p>
     */
    private DictItemView toItemView(DictItemRow item, String scopeId, String locale, boolean anonymous) {
        String label = StringUtils.hasText(item.labelI18nKey())
                ? i18nService.resolver(scopeId, locale, anonymous).of(item.labelI18nKey(), item.itemLabel())
                : item.itemLabel();
        return new DictItemView(
                item.id(),
                label,
                item.itemValue(),
                item.sortNo(),
                item.defaultItem(),
                item.color(),
                item.extraJson(),
                item.labelI18nKey(),
                item.status());
    }

    /** 只认平台语言字典中已启用的语言；其余一律按录入原文处理。 */
    private String supportedLocale(String language) {
        if (!StringUtils.hasText(language)) {
            return null;
        }
        String requested = language.split(",", 2)[0].split(";", 2)[0].trim();
        if (!StringUtils.hasText(requested)) return null;
        Set<String> enabledLocales = enabledLocaleCodes();
        return enabledLocales.stream()
                .filter(locale -> locale.equalsIgnoreCase(requested))
                .findFirst()
                .or(() -> {
                    String baseLanguage = requested.split("-", 2)[0];
                    return enabledLocales.stream()
                            .filter(locale ->
                                    locale.regionMatches(true, 0, baseLanguage + "-", 0, baseLanguage.length() + 1))
                            .findFirst();
                })
                .orElse(null);
    }

    private Set<String> enabledLocaleCodes() {
        return repository
                .enabledDictType(GLOBAL_SCOPE, LOCALE_DICT_CODE)
                .map(type -> repository.dictItems(type.id(), true).stream()
                        .map(DictItemRow::itemValue)
                        .filter(StringUtils::hasText)
                        .collect(java.util.stream.Collectors.toUnmodifiableSet()))
                .orElseGet(Set::of);
    }

    private static String normalize(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }

    private static String nextId() {
        return String.valueOf(ID_SEQUENCE.incrementAndGet());
    }

    /**
     * 参数配置的字段级变更。
     *
     * <p>**敏感配置的值一律不进 diff**：审计日志任何时候都不得保存密钥明文，
     * 也不能通过「改前是什么」把旧密钥泄露出去；这里只记录「值已变更」这个事实。
     * 新建时 {@code existing} 为 null，逐字段与 null 比较，diff 即完整初始值。</p>
     */
    private static List<FieldChange> configChanges(ConfigRow existing, ConfigRow row) {
        List<FieldChange> changes = new ArrayList<>();
        addChange(changes, "configKey", existing == null ? null : existing.configKey(), row.configKey());
        if (row.secret() || (existing != null && existing.secret())) {
            boolean valueChanged = existing == null || !Objects.equals(existing.configValue(), row.configValue());
            if (valueChanged) {
                changes.add(new FieldChange("configValue", MASKED_VALUE, MASKED_VALUE));
            }
        } else {
            addChange(changes, "configValue", existing == null ? null : existing.configValue(), row.configValue());
        }
        addChange(changes, "valueType", existing == null ? null : existing.valueType(), row.valueType());
        addChange(
                changes,
                "secret",
                existing == null ? null : String.valueOf(existing.secret()),
                String.valueOf(row.secret()));
        addChange(changes, "status", existing == null ? null : existing.status(), row.status());
        addChange(changes, "description", existing == null ? null : existing.description(), row.description());
        addChange(
                changes,
                "sortNo",
                existing == null ? null : String.valueOf(existing.sortNo()),
                String.valueOf(row.sortNo()));
        addChange(changes, "valueI18nKey", existing == null ? null : existing.valueI18nKey(), row.valueI18nKey());
        return changes;
    }

    /** 字典类型的字段级变更；新建时 {@code existing} 为 null，diff 即完整初始值。 */
    private static List<FieldChange> dictTypeChanges(DictTypeRow existing, DictTypeRow row) {
        List<FieldChange> changes = new ArrayList<>();
        addChange(changes, "dictCode", existing == null ? null : existing.dictCode(), row.dictCode());
        addChange(changes, "dictName", existing == null ? null : existing.dictName(), row.dictName());
        addChange(changes, "dictNameKey", existing == null ? null : existing.dictNameKey(), row.dictNameKey());
        addChange(
                changes,
                "inheritGlobal",
                existing == null ? null : String.valueOf(existing.inheritGlobal()),
                String.valueOf(row.inheritGlobal()));
        addChange(changes, "status", existing == null ? null : existing.status(), row.status());
        addChange(changes, "description", existing == null ? null : existing.description(), row.description());
        return changes;
    }

    /** 字典项的字段级变更；新建时 {@code existing} 为 null，diff 即完整初始值。 */
    private static List<FieldChange> dictItemChanges(DictItemRow existing, DictItemRow row) {
        List<FieldChange> changes = new ArrayList<>();
        addChange(changes, "itemLabel", existing == null ? null : existing.itemLabel(), row.itemLabel());
        addChange(changes, "itemValue", existing == null ? null : existing.itemValue(), row.itemValue());
        addChange(changes, "labelI18nKey", existing == null ? null : existing.labelI18nKey(), row.labelI18nKey());
        addChange(
                changes,
                "sortNo",
                existing == null ? null : String.valueOf(existing.sortNo()),
                String.valueOf(row.sortNo()));
        addChange(
                changes,
                "defaultItem",
                existing == null ? null : String.valueOf(existing.defaultItem()),
                String.valueOf(row.defaultItem()));
        addChange(changes, "color", existing == null ? null : existing.color(), row.color());
        addChange(changes, "extraJson", existing == null ? null : existing.extraJson(), row.extraJson());
        addChange(changes, "status", existing == null ? null : existing.status(), row.status());
        return changes;
    }

    /** 值未变化就不记入 diff——把没改的字段也列出来会让「改了什么」被噪音淹没。 */
    private static void addChange(List<FieldChange> changes, String field, String before, String after) {
        if (!Objects.equals(before, after)) {
            changes.add(new FieldChange(field, before, after));
        }
    }
}
