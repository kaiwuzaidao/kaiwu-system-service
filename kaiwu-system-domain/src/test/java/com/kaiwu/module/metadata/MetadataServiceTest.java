package com.kaiwu.module.metadata;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

import com.kaiwu.module.audit.AuditService;
import com.kaiwu.module.i18n.I18nService;
import com.kaiwu.module.metadata.MetadataRepository.ConfigRow;
import com.kaiwu.module.metadata.MetadataRepository.DictItemRow;
import com.kaiwu.module.metadata.MetadataRepository.DictTypeRow;
import com.kaiwu.module.metadata.dto.DictItemSaveRequest;
import com.kaiwu.module.project.ProjectRepository;
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
        service = new MetadataService(
                repository,
                projectRepository,
                new ConfigEncryptionService(Base64.getEncoder().encodeToString(new byte[32])),
                mock(AuditService.class),
                new ObjectMapper(),
                i18nService,
                Clock.systemDefaultZone());
        // 空目录快照：本类不验国际化，解析一律回退录入原文。
        when(i18nService.resolver(any(), anyBoolean())).thenReturn(new I18nService.LocalizedText(Map.of()));
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
        when(i18nService.resolver(eq("en-US"), anyBoolean()))
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
        when(i18nService.resolver(eq("en-US"), anyBoolean())).thenReturn(new I18nService.LocalizedText(Map.of()));
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
        when(i18nService.resolver(eq("ja-JP"), anyBoolean()))
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
