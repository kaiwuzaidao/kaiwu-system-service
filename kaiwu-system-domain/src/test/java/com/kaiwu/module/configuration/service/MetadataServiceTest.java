package com.kaiwu.module.configuration.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

import com.kaiwu.module.configuration.repository.MetadataRepository;
import com.kaiwu.module.configuration.repository.MetadataRepository.ConfigRow;
import com.kaiwu.module.configuration.repository.MetadataRepository.DictItemRow;
import com.kaiwu.module.configuration.repository.MetadataRepository.DictTypeRow;
import com.kaiwu.module.configuration.service.MetadataService.ConfigDeleteSnapshot;
import com.kaiwu.module.configuration.service.MetadataService.DictItemDeleteSnapshot;
import com.kaiwu.module.configuration.service.MetadataService.DictItemRenameExpectation;
import com.kaiwu.module.configuration.service.MetadataService.DictTypeRenameExpectation;
import com.kaiwu.module.configuration.service.impl.MetadataServiceImpl;
import com.kaiwu.module.metadata.dto.ConfigSaveRequest;
import com.kaiwu.module.metadata.dto.DictItemSaveRequest;
import com.kaiwu.module.operation.service.AuditService;
import com.kaiwu.module.project.repository.ProjectRepository;
import com.kaiwu.module.project.vo.ProjectView;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

class MetadataServiceTest {

    private MetadataRepository repository;

    private I18nService i18nService;
    private ProjectRepository projectRepository;
    private MetadataService service;

    @BeforeEach
    void setUp() {
        i18nService = mock(I18nService.class);
        repository = mock(MetadataRepository.class);
        projectRepository = mock(ProjectRepository.class);
        service = new MetadataServiceImpl(
                repository,
                projectRepository,
                new ConfigEncryptionService(Base64.getEncoder().encodeToString(new byte[32])),
                mock(AuditService.class),
                new ObjectMapper(),
                i18nService,
                Clock.systemDefaultZone());
        // 空目录快照：本类不验国际化，解析一律回退录入原文。
        when(i18nService.resolver(any(), any(), anyBoolean())).thenReturn(new I18nService.LocalizedText(Map.of()));
        when(projectRepository.findProject("10")).thenReturn(Optional.of(project()));
        when(projectRepository.activeMemberExists("10", "1")).thenReturn(true);
        stubLocales(item("201", "200", "简体中文", "zh-CN"), item("202", "200", "English (US)", "en-US"));
    }

    @Test
    void effectiveConfigUsesProjectOverrideAndNeverReturnsSecret() {
        when(repository.configs("0", true))
                .thenReturn(List.of(
                        config("1", "0", "app.admin.brand", "Kaiwu", false),
                        config("2", "0", "internal.secret", "cipher", true)));
        when(repository.configs("10", true)).thenReturn(List.of(config("3", "10", "app.admin.brand", "演示项目", false)));

        var result = service.effectiveConfigs("10", "1", null);

        assertThat(result).singleElement().satisfies(item -> {
            assertThat(item.key()).isEqualTo("app.admin.brand");
            assertThat(item.value()).isEqualTo("演示项目");
            assertThat(item.sourceScopeId()).isEqualTo("10");
        });
    }

    @Test
    void platformUiPreferencesOnlyExposeBoundedNonSecretValues() {
        when(repository.configs("0", true))
                .thenReturn(List.of(
                        config("1", "0", "platform.notification.poll_seconds", "120", false),
                        config("2", "0", "platform.factory.poll_seconds", "999999", false),
                        config("3", "0", "internal.secret", "cipher", true)));

        assertThat(service.platformUiPreferences())
                .containsEntry("platform.notification.poll_seconds", 120)
                .containsEntry("platform.factory.poll_seconds", 3)
                .doesNotContainKey("internal.secret");
    }

    @Test
    void platformUiPreferencesRejectOutOfRangeProjectAndSecretWrites() {
        var tooFast = new ConfigSaveRequest(
                null, "platform.notification.poll_seconds", "1", null, "NUMBER", false, "ENABLED", null, 0);
        var projectOverride = new ConfigSaveRequest(
                null, "platform.factory.poll_seconds", "10", null, "NUMBER", false, "ENABLED", null, 0);
        var secret = new ConfigSaveRequest(
                null, "platform.factory.poll_seconds", "10", null, "NUMBER", true, "ENABLED", null, 0);
        var translated = new ConfigSaveRequest(
                null, "platform.factory.poll_seconds", "10", "example.text", "NUMBER", false, "ENABLED", null, 0);
        var invalidPage =
                new ConfigSaveRequest(null, "common.table.page_size", "201", null, "NUMBER", false, "ENABLED", null, 0);
        assertThatThrownBy(() -> service.saveConfig("10", invalidPage, null, null))
                .hasMessageContaining("5–200");
        assertThatThrownBy(() -> service.saveConfig("0", tooFast, null, null)).hasMessageContaining("15");
        assertThatThrownBy(() -> service.saveConfig("10", projectOverride, null, null))
                .hasMessageContaining("全局");
        assertThatThrownBy(() -> service.saveConfig("0", secret, null, null)).hasMessageContaining("非敏感");
        assertThatThrownBy(() -> service.saveConfig("0", translated, null, null))
                .hasMessageContaining("国际化");
        verify(repository, never()).saveConfig(any(), anyBoolean());
    }

    @Test
    void projectDictionaryOverridesSameGlobalValueAndInheritsOthers() {
        DictTypeRow global = type("100", "0", true);
        DictTypeRow project = type("101", "10", true);
        when(repository.enabledDictType("0", "demo.status")).thenReturn(Optional.of(global));
        when(repository.enabledDictType("10", "demo.status")).thenReturn(Optional.of(project));
        when(repository.dictItems("100", true))
                .thenReturn(List.of(item("1", "100", "待处理", "PENDING"), item("2", "100", "完成", "DONE")));
        when(repository.dictItems("101", true)).thenReturn(List.of(item("3", "101", "项目待办", "PENDING")));

        var result = service.effectiveDict("10", "demo.status", "1");

        assertThat(result.items()).extracting("itemLabel").containsExactly("项目待办", "完成");
    }

    @Test
    void dictionaryLabelUsesReferencedResourceForRequestedLanguage() {
        // ADR 0015：译文只来自引用的资源，内联列已退役。
        when(i18nService.resolver(any(), eq("en-US"), anyBoolean()))
                .thenReturn(new I18nService.LocalizedText(Map.of(
                        "dict.demo.status.PENDING", "Pending",
                        "dict.demo.status.DONE", "Done")));
        stubDictionary(
                item("1", "100", "待处理", "PENDING", "dict.demo.status.PENDING"),
                item("2", "100", "完成", "DONE", "dict.demo.status.DONE"));

        var result = service.effectiveDict("10", "demo.status", "1", "en-US");

        assertThat(result.items()).extracting("itemLabel").containsExactly("Pending", "Done");
    }

    @Test
    void dictionaryLabelFallsBackToEnteredTextWhenResourceMissing() {
        // 目录里没有该 key（未翻译或资源被删）时回退录入原文，
        // 绝不把 key 本身显示给用户。
        when(i18nService.resolver(any(), eq("en-US"), anyBoolean()))
                .thenReturn(new I18nService.LocalizedText(Map.of()));
        stubDictionary(
                item("1", "100", "待处理", "PENDING", "dict.demo.status.PENDING"),
                // 未引用任何资源：独立填写，只有单一原文
                item("2", "100", "完成", "DONE", null));

        var result = service.effectiveDict("10", "demo.status", "1", "en-US");

        assertThat(result.items()).extracting("itemLabel").containsExactly("待处理", "完成");
    }

    @Test
    void dictionaryLabelIgnoresTranslationForUnsupportedLanguage() {
        stubDictionary(item("1", "100", "待处理", "PENDING", "dict.demo.status.PENDING"));

        // 平台只发布 zh-CN / en-US；其它语言一律按录入原文，不半翻译。
        var result = service.effectiveDict("10", "demo.status", "1", "ja-JP");

        assertThat(result.items()).extracting("itemLabel").containsExactly("待处理");
    }

    @Test
    void dictionaryLabelUsesLanguageAddedToLocaleDictionary() {
        stubLocales(
                item("201", "200", "简体中文", "zh-CN"),
                item("202", "200", "English (US)", "en-US"),
                item("203", "200", "日本語", "ja-JP"));
        when(i18nService.resolver(any(), eq("ja-JP"), anyBoolean()))
                .thenReturn(new I18nService.LocalizedText(Map.of("dict.demo.status.PENDING", "保留")));
        stubDictionary(item("1", "100", "待处理", "PENDING", "dict.demo.status.PENDING"));

        var result = service.effectiveDict("10", "demo.status", "1", "ja-JP");

        assertThat(result.items()).extracting("itemLabel").containsExactly("保留");
    }

    @Test
    void rejectsReferenceToNonExistentResource() {
        // 引用不存在的资源必须在写入时拒绝：留到展示时才发现意味着保存已经成功、
        // 界面却显示不出文案（ADR 0013 第 6 节）。
        when(repository.dictType("100")).thenReturn(Optional.of(type("100", "0", true)));
        when(repository.dictValueExists("100", "PENDING", null)).thenReturn(false);
        when(i18nService.messageKeyExists("dict.demo.status.MISSING")).thenReturn(false);

        DictItemSaveRequest request = new DictItemSaveRequest(
                null, "待处理", "PENDING", 0, false, null, null, "dict.demo.status.MISSING", "ENABLED");

        assertThatThrownBy(() -> service.saveDictItem("0", "100", request, null, null))
                .hasMessageContaining("国际化资源不存在");
    }

    @Test
    void dictionaryRenamePreservesOtherFieldsAfterLockedComparison() {
        DictTypeRow before = type("100", "0", false);
        when(repository.dictTypeForUpdate("100")).thenReturn(Optional.of(before));
        when(repository.dictType("100"))
                .thenReturn(Optional.of(new DictTypeRow(
                        before.id(),
                        before.scopeId(),
                        before.dictCode(),
                        "新名称",
                        before.dictNameKey(),
                        before.inheritGlobal(),
                        before.sortNo(),
                        before.status(),
                        before.description(),
                        before.createdAt(),
                        before.updatedAt())));

        var result = service.renameGlobalDictType(
                "100", "新名称", new DictTypeRenameExpectation("demo.status", "状态", "ENABLED", ""), null, null);

        assertThat(result.dictName()).isEqualTo("新名称");
        verify(repository)
                .saveDictType(
                        argThat(row -> row.id().equals("100")
                                && row.dictCode().equals("demo.status")
                                && row.dictName().equals("新名称")
                                && row.status().equals("ENABLED")),
                        eq(false));
    }

    @Test
    void dictionaryRenameRejectsChangesSincePreview() {
        DictTypeRow before = type("100", "0", false);
        when(repository.dictTypeForUpdate("100"))
                .thenReturn(Optional.of(new DictTypeRow(
                        before.id(),
                        before.scopeId(),
                        before.dictCode(),
                        "其他人已修改",
                        before.dictNameKey(),
                        before.inheritGlobal(),
                        before.sortNo(),
                        before.status(),
                        before.description(),
                        before.createdAt(),
                        before.updatedAt())));

        assertThatThrownBy(() -> service.renameGlobalDictType(
                        "100", "新名称", new DictTypeRenameExpectation("demo.status", "状态", "ENABLED", ""), null, null))
                .hasMessageContaining("字典已变化");
        verify(repository, never()).saveDictType(any(), anyBoolean());
    }

    @Test
    void dictionaryItemRenamePreservesStableValueAndSettings() {
        DictItemRow before = item("11", "100", "原标签", "stable");
        when(repository.dictType("100")).thenReturn(Optional.of(type("100", "0", false)));
        when(repository.dictItemForUpdate("11")).thenReturn(Optional.of(before));
        when(repository.dictItem("11")).thenReturn(Optional.of(item("11", "100", "新标签", "stable")));

        var result = service.renameGlobalDictItem(
                "100", "11", "新标签", new DictItemRenameExpectation("原标签", "stable", "ENABLED"), null, null);

        assertThat(result.itemLabel()).isEqualTo("新标签");
        verify(repository)
                .saveDictItem(
                        argThat(row -> row.id().equals("11")
                                && row.itemLabel().equals("新标签")
                                && row.itemValue().equals("stable")
                                && row.status().equals("ENABLED")),
                        eq(false));
    }

    @Test
    void dictionaryItemRenameRejectsStalePreview() {
        when(repository.dictType("100")).thenReturn(Optional.of(type("100", "0", false)));
        when(repository.dictItemForUpdate("11")).thenReturn(Optional.of(item("11", "100", "其他人已修改", "stable")));

        assertThatThrownBy(() -> service.renameGlobalDictItem(
                        "100", "11", "新标签", new DictItemRenameExpectation("原标签", "stable", "ENABLED"), null, null))
                .hasMessageContaining("字典项已变化");
        verify(repository, never()).saveDictItem(any(), anyBoolean());
    }

    @Test
    void agentDictionaryItemDeletionChecksFrozenIdentityAndGlobalScope() {
        DictItemRow before = item("11", "100", "原标签", "stable");
        when(repository.dictType("100")).thenReturn(Optional.of(type("100", "0", false)));
        when(repository.dictItem("11")).thenReturn(Optional.of(before));
        when(repository.dictItemForUpdate("11")).thenReturn(Optional.of(before));

        var preview = service.previewGlobalDictItemDeletion("100", "11");
        assertThat(preview).isEqualTo(new DictItemDeleteSnapshot("原标签", "stable", "ENABLED"));
        service.deleteGlobalDictItemForAgent("100", "11", preview, null, null);
        verify(repository).deleteDictItem("11");

        when(repository.dictItemForUpdate("11")).thenReturn(Optional.of(item("11", "100", "其他人已修改", "stable")));
        assertThatThrownBy(() -> service.deleteGlobalDictItemForAgent("100", "11", preview, null, null))
                .hasMessageContaining("字典项已变化");
        verify(repository, times(1)).deleteDictItem("11");

        when(repository.dictType("100")).thenReturn(Optional.of(type("100", "10", false)));
        assertThatThrownBy(() -> service.previewGlobalDictItemDeletion("100", "11"))
                .isInstanceOf(com.kaiwu.common.ApiException.class);
    }

    @Test
    void agentDictionaryTypeDeletionRejectsChangedChildrenAndProjectScope() {
        DictTypeRow global = type("100", "0", false);
        DictItemRow child = item("11", "100", "原标签", "stable");
        when(repository.dictType("100")).thenReturn(Optional.of(global));
        when(repository.dictTypeForUpdate("100")).thenReturn(Optional.of(global));
        when(repository.dictItems("100", false)).thenReturn(List.of(child));
        when(repository.dictItemsForUpdate("100")).thenReturn(List.of(child));

        var preview = service.previewGlobalDictTypeDeletion("100");
        assertThat(preview.itemCount()).isEqualTo(1);
        service.deleteGlobalDictTypeForAgent("100", preview, null, null);
        verify(repository).deleteDictType("100");

        when(repository.dictItemsForUpdate("100")).thenReturn(List.of(item("11", "100", "新标签", "stable")));
        assertThatThrownBy(() -> service.deleteGlobalDictTypeForAgent("100", preview, null, null))
                .hasMessageContaining("字典已变化");
        verify(repository, times(1)).deleteDictType("100");

        when(repository.dictType("100")).thenReturn(Optional.of(type("100", "10", false)));
        assertThatThrownBy(() -> service.previewGlobalDictTypeDeletion("100"))
                .isInstanceOf(com.kaiwu.common.ApiException.class);
    }

    @Test
    void agentGlobalConfigDeletionUsesLockedSnapshotWithoutExposingValue() {
        ConfigRow before = config("31", "0", "api.secret", "encrypted-ciphertext", true);
        when(repository.config("31")).thenReturn(Optional.of(before));
        when(repository.configForUpdate("31")).thenReturn(Optional.of(before));

        ConfigDeleteSnapshot snapshot = service.previewGlobalConfigDeletion("31");
        assertThat(snapshot.configKey()).isEqualTo("api.secret");
        assertThat(snapshot.secret()).isTrue();
        assertThat(snapshot.toString()).doesNotContain("encrypted-ciphertext");
        service.deleteGlobalConfigForAgent("31", snapshot, null, null);
        verify(repository).deleteConfig("31");

        when(repository.configForUpdate("31"))
                .thenReturn(Optional.of(config("31", "0", "api.secret", "changed-ciphertext", true)));
        assertThatThrownBy(() -> service.deleteGlobalConfigForAgent("31", snapshot, null, null))
                .hasMessageContaining("配置已变化");
        verify(repository, times(1)).deleteConfig("31");

        when(repository.config("31")).thenReturn(Optional.of(config("31", "10", "api.secret", "x", true)));
        assertThatThrownBy(() -> service.previewGlobalConfigDeletion("31"))
                .isInstanceOf(com.kaiwu.common.ApiException.class);
    }

    private void stubDictionary(DictItemRow... items) {
        when(repository.enabledDictType("0", "demo.status")).thenReturn(Optional.of(type("100", "0", true)));
        when(repository.enabledDictType("10", "demo.status")).thenReturn(Optional.empty());
        when(repository.dictItems("100", true)).thenReturn(List.of(items));
    }

    private void stubLocales(DictItemRow... items) {
        when(repository.enabledDictType("0", "platform.locale")).thenReturn(Optional.of(localeType()));
        when(repository.dictItems("200", true)).thenReturn(List.of(items));
    }

    private static ConfigRow config(String id, String scopeId, String key, String value, boolean secret) {
        LocalDateTime now = LocalDateTime.now();
        return new ConfigRow(id, scopeId, key, value, null, "STRING", secret, "ENABLED", null, 0, now, now);
    }

    private static DictTypeRow type(String id, String scopeId, boolean inherit) {
        LocalDateTime now = LocalDateTime.now();
        return new DictTypeRow(id, scopeId, "demo.status", "状态", null, inherit, 0, "ENABLED", null, now, now);
    }

    private static DictTypeRow localeType() {
        LocalDateTime now = LocalDateTime.now();
        return new DictTypeRow("200", "0", "platform.locale", "平台语言", null, false, 0, "ENABLED", null, now, now);
    }

    private static DictItemRow item(String id, String typeId, String label, String value) {
        return item(id, typeId, label, value, null);
    }

    private static DictItemRow item(String id, String typeId, String label, String value, String labelI18nKey) {
        return new DictItemRow(id, typeId, label, value, 0, false, null, null, "ENABLED", null, labelI18nKey);
    }

    private static ProjectView project() {
        LocalDateTime now = LocalDateTime.now();
        return new ProjectView(
                "10",
                "demo",
                "演示项目",
                null,
                "ACTIVE",
                false,
                "1",
                "com.kaiwu.business.demo",
                null,
                null,
                "main",
                null,
                null,
                null,
                now,
                now);
    }
}
