package com.kaiwu.module.i18n;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

import com.kaiwu.module.audit.AuditService;
import com.kaiwu.module.i18n.I18nRepository.LocaleRow;
import com.kaiwu.module.i18n.I18nRepository.MessageRow;
import com.kaiwu.module.i18n.dto.I18nMessageSaveRequest;
import java.time.LocalDateTime;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

class I18nServiceTest {

    private I18nRepository repository;
    private I18nService service;

    @BeforeEach
    void setUp() {
        repository = mock(I18nRepository.class);
        ObjectMapper objectMapper = new ObjectMapper();
        AuditService auditService = mock(AuditService.class);
        I18nCatalogService catalogService = new I18nCatalogService(repository, objectMapper);
        service = new I18nService(
                catalogService,
                new I18nMessageService(repository, auditService, objectMapper, catalogService),
                new I18nWorkbookService(repository, new I18nTranslationWorkbookCodec(), auditService, catalogService));
        when(repository.enabledLocales()).thenReturn(List.of("zh-CN", "en-US", "ja-JP"));
        when(repository.revision()).thenReturn(7L);
    }

    @Test
    void catalogUsesConfiguredTranslation() {
        when(repository.messages(true, false))
                .thenReturn(List.of(row("common.save", "保存", "{\"en-US\":\"Save\",\"ja-JP\":\"保存\"}")));

        var catalog = service.catalog("ja-JP", false);

        assertThat(catalog.revision()).isEqualTo(7);
        assertThat(catalog.messages()).containsEntry("common.save", "保存");
    }

    @Test
    void rejectsLocaleOutsidePlatformLocaleDictionary() {
        assertThatThrownBy(() -> service.catalog("jp", false)).hasMessageContaining("暂不支持该语言");
    }

    @Test
    void localeDirectoryUsesItsOwnLabelTranslations() {
        // ADR 0015：语言名译文也存在资源目录里，不再读已退役的内联列。
        when(repository.locales())
                .thenReturn(List.of(
                        new LocaleRow("ja-JP", "日语", "dict.platform.locale.ja-JP", "{\"selectable\":false}", false)));
        when(repository.messages(true, false))
                .thenReturn(List.of(new MessageRow(
                        "9",
                        "dict.platform.locale.ja-JP",
                        "日语",
                        "{\"en-US\":\"Japanese\"}",
                        "dict",
                        false,
                        false,
                        "ENABLED",
                        null,
                        1,
                        LocalDateTime.now())));
        when(repository.missingRequiredResources(eq("ja-JP"), anyString())).thenReturn(1L);
        when(repository.missingMenus(eq("ja-JP"), anyString())).thenReturn(0L);
        when(repository.missingDictionaryItems(eq("ja-JP"), anyString())).thenReturn(12L);

        var locales = service.locales("en-US");

        assertThat(locales).singleElement().satisfies(locale -> {
            assertThat(locale.label()).isEqualTo("Japanese");
            assertThat(locale.selectable()).isFalse();
            assertThat(locale.missingRequiredResources()).isEqualTo(1);
            assertThat(locale.missingMenus()).isZero();
            assertThat(locale.missingDictionaryItems()).isEqualTo(12);
        });
    }

    @Test
    void rejectsTranslationWithDifferentPlaceholders() {
        I18nMessageSaveRequest request = new I18nMessageSaveRequest(
                null,
                "project.created",
                "项目 {name} 已创建",
                "{\"en-US\":\"Project created\"}",
                "project",
                false,
                true,
                "ENABLED",
                null,
                null);

        assertThatThrownBy(() -> service.save(request, null, null)).hasMessageContaining("占位符");
        verify(repository, never()).insert(any());
    }

    @Test
    void rejectsStaleVersionInsteadOfOverwritingTranslations() {
        MessageRow existing = row("common.save", "保存", "{\"en-US\":\"Save\"}");
        when(repository.message("1")).thenReturn(Optional.of(existing));
        when(repository.update(any(), eq(3L))).thenReturn(false);
        I18nMessageSaveRequest request = new I18nMessageSaveRequest(
                "1", "common.save", "保存", "{\"en-US\":\"Save now\"}", "common", false, true, "ENABLED", null, 3L);

        assertThatThrownBy(() -> service.save(request, null, null)).hasMessageContaining("刷新后重试");
        verify(repository, never()).bumpRevision();
    }

    @Test
    void rejectsChangingStableMessageKey() {
        when(repository.message("1")).thenReturn(Optional.of(row("common.save", "保存", "{\"en-US\":\"Save\"}")));
        I18nMessageSaveRequest request = new I18nMessageSaveRequest(
                "1", "common.save.renamed", "保存", "{\"en-US\":\"Save\"}", "common", false, true, "ENABLED", null, 4L);

        assertThatThrownBy(() -> service.save(request, null, null)).hasMessageContaining("不可修改");
        verify(repository, never()).update(any(), anyLong());
    }

    /**
     * 覆盖门禁是全有全无且在读取时生效的，缺一条译文就会让整门语言掉出选择器，
     * 已选该语言的用户会被静默切回默认语言且无法自己切回。写入阶段必须先拦住。
     */
    @Test
    void rejectsRequiredResourceMissingTranslationForOpenLocale() {
        openLocale("en-US");
        I18nMessageSaveRequest request = new I18nMessageSaveRequest(
                null, "project.created", "项目已创建", null, "project", false, true, "ENABLED", null, null);

        assertThatThrownBy(() -> service.save(request, null, null)).hasMessageContaining("en-US");
        verify(repository, never()).insert(any());
    }

    /** 非覆盖必需资源不影响语言可选状态，允许先建 key 再补译文。 */
    @Test
    void allowsOptionalResourceWithoutTranslationForOpenLocale() {
        openLocale("en-US");
        when(repository.message(anyString())).thenReturn(Optional.empty());
        I18nMessageSaveRequest request = new I18nMessageSaveRequest(
                null, "project.draft", "草稿", null, "project", false, false, "ENABLED", null, null);

        assertThatThrownBy(() -> service.save(request, null, null)).isInstanceOf(NoSuchElementException.class);
        verify(repository).insert(any());
    }

    /** 匿名 catalog 只允许最小救援范围；管理端不能把任意业务文案标成登录前公开。 */
    @Test
    void rejectsPublicVisibleOutsideRescueScope() {
        I18nMessageSaveRequest request = new I18nMessageSaveRequest(
                null, "project.created", "项目已创建", null, "project", true, false, "ENABLED", null, null);

        assertThatThrownBy(() -> service.save(request, null, null)).hasMessageContaining("不允许匿名公开");
        verify(repository, never()).insert(any());
    }

    /** 登录页文案必须能匿名下发，否则后台编辑不生效、新增语言也翻不到登录页。 */
    @Test
    void allowsPublicVisibleForLoginAndRescueKeys() {
        when(repository.message(anyString())).thenReturn(Optional.empty());

        for (String key : List.of(
                "login.form.title", "client.sessionExpired", "client.catalogFailed", "common.language.updated")) {
            I18nMessageSaveRequest request =
                    new I18nMessageSaveRequest(null, key, "文案", null, "login", true, false, "ENABLED", null, null);
            assertThatThrownBy(() -> service.save(request, null, null))
                    .as("%s 应通过公开范围校验", key)
                    .isInstanceOf(NoSuchElementException.class);
        }
    }

    /** 让某门语言处于"已配置且覆盖完整"，即已对用户开放。 */
    private void openLocale(String locale) {
        // 目标语言必须是「已开放的非默认语言」：默认语言用原文，按设计豁免译文校验，
        // 若把它标成默认语言，这里要验的规则根本不会执行。
        when(repository.locales())
                .thenReturn(List.of(
                        new LocaleRow("zh-CN", "简体中文", null, "{\"selectable\":true}", true),
                        new LocaleRow(locale, locale, null, "{\"selectable\":true}", false)));
        when(repository.missingRequiredResources(eq(locale), anyString())).thenReturn(0L);
        when(repository.missingMenus(eq(locale), anyString())).thenReturn(0L);
        when(repository.missingDictionaryItems(eq(locale), anyString())).thenReturn(0L);
    }

    private static MessageRow row(String key, String text, String translations) {
        return new MessageRow(
                "1", key, text, translations, "common", false, true, "ENABLED", null, 4, LocalDateTime.now());
    }
}
