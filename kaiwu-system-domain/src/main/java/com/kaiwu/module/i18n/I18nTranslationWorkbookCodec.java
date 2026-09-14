package com.kaiwu.module.i18n;

import com.kaiwu.common.ApiException;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.apache.poi.xssf.streaming.SXSSFWorkbook;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * 译文批量导出与导入的 Excel 编解码。
 *
 * <p>存在的意义：开放一门新语言要求资源、菜单和字典译文全部补齐，平台侧有近千条，
 * 逐条在界面上填不现实。导出后离线翻译、再整表导回，是唯一可行的补齐路径。</p>
 *
 * <p>三类内容各占一个 Sheet，一次导出、一次导入即可覆盖全部缺口。导入按 key 匹配，
 * <b>只写目标语言那一列</b>：默认文案、模块、状态等仍由界面维护，避免把展示用的表格
 * 变成第二个写入入口。</p>
 */
@Component
public class I18nTranslationWorkbookCodec {

    /** 与用户导入一致的量级上限：结果集整体进内存，无上限会 OOM。 */
    private static final int MAX_ROWS = 20_000;

    private static final int MAX_FILE_BYTES = 10 * 1024 * 1024;

    static final String SHEET_RESOURCE = "resources";
    static final String SHEET_MENU = "menus";
    static final String SHEET_DICT = "dictionaries";

    /**
     * @param locale 目标语言，用作译文列表头
     * @param rows   三类待翻译条目，key 为 sheet 名
     */
    public byte[] export(String locale, Map<String, List<TranslationRow>> rows) {
        try (SXSSFWorkbook workbook = new SXSSFWorkbook(100);
                ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            workbook.setCompressTempFiles(true);
            for (Map.Entry<String, List<TranslationRow>> entry : rows.entrySet()) {
                writeSheet(workbook, entry.getKey(), locale, entry.getValue());
            }
            workbook.write(output);
            workbook.dispose();
            return output.toByteArray();
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "导出译文失败", "api.i18n.exportFailed");
        }
    }

    private void writeSheet(SXSSFWorkbook workbook, String sheetName, String locale, List<TranslationRow> rows) {
        Sheet sheet = workbook.createSheet(sheetName);
        Row header = sheet.createRow(0);
        // 列顺序即导入时的解析顺序，改动会让既有翻译文件失效。
        header.createCell(0).setCellValue("key");
        header.createCell(1).setCellValue("默认文案");
        header.createCell(2).setCellValue(locale);
        header.createCell(3).setCellValue("说明");
        int index = 1;
        for (TranslationRow row : rows) {
            Row line = sheet.createRow(index++);
            line.createCell(0).setCellValue(row.key());
            line.createCell(1).setCellValue(nullToEmpty(row.defaultText()));
            line.createCell(2).setCellValue(nullToEmpty(row.translation()));
            line.createCell(3).setCellValue(nullToEmpty(row.description()));
        }
    }

    /**
     * 解析导入文件。
     *
     * <p>只认识导出时写下的列序；缺失的 sheet 视为本次不导入该类内容，
     * 允许用户只翻译其中一部分再导回。</p>
     */
    public Map<String, List<ImportedTranslation>> parse(byte[] bytes) {
        if (bytes == null || bytes.length == 0 || bytes.length > MAX_FILE_BYTES) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Excel 文件大小必须在 1B 到 10MB 之间", "api.i18n.importFileInvalid");
        }
        Map<String, List<ImportedTranslation>> result = new LinkedHashMap<>();
        try (Workbook workbook = WorkbookFactory.create(new ByteArrayInputStream(bytes))) {
            for (String name : List.of(SHEET_RESOURCE, SHEET_MENU, SHEET_DICT)) {
                Sheet sheet = workbook.getSheet(name);
                if (sheet != null) {
                    result.put(name, readSheet(sheet));
                }
            }
        } catch (ApiException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "无法解析 Excel 文件", "api.i18n.importFileInvalid");
        }
        if (result.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "文件中没有可识别的工作表", "api.i18n.importSheetMissing");
        }
        return result;
    }

    private List<ImportedTranslation> readSheet(Sheet sheet) {
        List<ImportedTranslation> rows = new ArrayList<>();
        int last = sheet.getLastRowNum();
        if (last > MAX_ROWS) {
            // 上限走 messageArgs 而不是字符串拼接：拼接后译文只能写死数字或干脆丢掉它，
            // 用户就看不出该缩到多少行。与 api.user.export.tooManyRows 的既有约定一致。
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "单个工作表不能超过 " + MAX_ROWS + " 行",
                    "api.i18n.importTooManyRows",
                    Map.of("limit", MAX_ROWS));
        }
        for (int index = 1; index <= last; index++) {
            Row row = sheet.getRow(index);
            if (row == null) continue;
            String key = text(row.getCell(0));
            String translation = text(row.getCell(2));
            // 只收有 key 的行；译文留空表示这条本次不翻译，跳过而不是写入空串——
            // 写空串会让覆盖率校验误判为"已翻译"。
            if (key.isBlank() || translation.isBlank()) continue;
            rows.add(new ImportedTranslation(index + 1, key, translation));
        }
        return rows;
    }

    private static String text(Cell cell) {
        if (cell == null) return "";
        return switch (cell.getCellType()) {
            case STRING -> cell.getStringCellValue().trim();
            case NUMERIC -> String.valueOf((long) cell.getNumericCellValue());
            case BOOLEAN -> String.valueOf(cell.getBooleanCellValue());
            default -> "";
        };
    }

    private static String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    /** 导出行：key + 默认文案 + 当前译文 + 说明。 */
    public record TranslationRow(String key, String defaultText, String translation, String description) {}

    /** 导入行：rowNumber 用于把失败原因定位回用户的文件。 */
    public record ImportedTranslation(int rowNumber, String key, String translation) {}
}
