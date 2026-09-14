package com.kaiwu.module.i18n;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.audit.AuditService;
import com.kaiwu.starter.KaiwuContext;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;

/** 国际化译文工作簿的导出、导入和逐行失败汇总。 */
@Component
final class I18nWorkbookService {

    private static final int MAX_REPORTED_FAILURES = 50;

    private final I18nRepository repository;
    private final I18nTranslationWorkbookCodec workbookCodec;
    private final AuditService auditService;
    private final I18nCatalogService catalogService;

    I18nWorkbookService(
            I18nRepository repository,
            I18nTranslationWorkbookCodec workbookCodec,
            AuditService auditService,
            I18nCatalogService catalogService) {
        this.repository = repository;
        this.workbookCodec = workbookCodec;
        this.auditService = auditService;
        this.catalogService = catalogService;
    }

    byte[] exportTranslations(String locale) {
        String target = catalogService.requireTranslatableLocale(locale);
        Map<String, List<I18nTranslationWorkbookCodec.TranslationRow>> sheets = new LinkedHashMap<>();
        sheets.put(I18nTranslationWorkbookCodec.SHEET_RESOURCE, toRows(repository.exportResources(target)));
        sheets.put(I18nTranslationWorkbookCodec.SHEET_MENU, toRows(repository.exportMenus()));
        sheets.put(I18nTranslationWorkbookCodec.SHEET_DICT, toRows(repository.exportDictionaryItems(target)));
        return workbookCodec.export(target, sheets);
    }

    I18nService.TranslationImportResult importTranslations(
            String locale, byte[] bytes, KaiwuContext actor, RequestMetadata metadata) {
        String target = catalogService.requireTranslatableLocale(locale);
        Map<String, List<I18nTranslationWorkbookCodec.ImportedTranslation>> sheets = workbookCodec.parse(bytes);
        int applied = 0;
        List<String> failures = new ArrayList<>();
        for (var entry : sheets.entrySet()) {
            for (var row : entry.getValue()) {
                int affected = upsert(entry.getKey(), row, target);
                if (affected > 0) {
                    applied++;
                } else if (failures.size() < MAX_REPORTED_FAILURES) {
                    failures.add(entry.getKey() + " 第 " + row.rowNumber() + " 行：找不到 " + row.key());
                }
            }
        }
        repository.bumpRevision();
        catalogService.invalidate();
        auditService.recordOperationInCallerTransaction(
                actor,
                "i18n",
                "IMPORT_TRANSLATIONS",
                "/api/i18n/translations/import",
                "locale=" + target + ",applied=" + applied + ",failed=" + failures.size(),
                metadata);
        return new I18nService.TranslationImportResult(applied, failures);
    }

    private int upsert(String sheet, I18nTranslationWorkbookCodec.ImportedTranslation row, String locale) {
        return switch (sheet) {
            case I18nTranslationWorkbookCodec.SHEET_RESOURCE ->
                repository.upsertResourceTranslation(row.key(), locale, row.translation());
            case I18nTranslationWorkbookCodec.SHEET_MENU ->
                repository.upsertMenuTranslation(row.key(), locale, row.translation());
            case I18nTranslationWorkbookCodec.SHEET_DICT ->
                repository.upsertDictionaryTranslation(row.key(), locale, row.translation());
            default -> 0;
        };
    }

    private static List<I18nTranslationWorkbookCodec.TranslationRow> toRows(
            List<I18nRepository.TranslationExportRow> rows) {
        return rows.stream()
                .map(row -> new I18nTranslationWorkbookCodec.TranslationRow(
                        row.key(), row.defaultText(), row.translation(), row.description()))
                .toList();
    }
}
