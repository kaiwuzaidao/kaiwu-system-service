package com.kaiwu.module.user;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.user.vo.UserView;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.apache.poi.xssf.streaming.SXSSFWorkbook;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
public class UserWorkbookCodec {

    private static final int MAX_ROWS = 5_000;
    private static final List<String> ZH_HEADERS = List.of("用户名*", "姓名*", "邮箱", "状态", "部门编码（多个用英文逗号分隔）", "初始密码*");
    private static final List<String> EN_HEADERS = List.of(
            "Username*", "Display name*", "Email", "Status", "Department codes (comma-separated)", "Initial password*");

    public byte[] exportUsers(List<UserView> users) {
        return exportUsers(users, "zh-CN");
    }

    /** 生成用户 Excel；表头随请求语言切换，列顺序与导入模板保持一致。 */
    public byte[] exportUsers(List<UserView> users, String language) {
        boolean english = language != null && language.toLowerCase(Locale.ROOT).startsWith("en");
        List<String> headers = english ? EN_HEADERS : ZH_HEADERS;
        try (SXSSFWorkbook workbook = new SXSSFWorkbook(100);
                ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            workbook.setCompressTempFiles(true);
            Sheet sheet = workbook.createSheet(english ? "Users" : "用户");
            Row header = sheet.createRow(0);
            for (int index = 0; index < headers.size(); index++) {
                header.createCell(index).setCellValue(headers.get(index));
            }
            int rowIndex = 1;
            for (UserView user : users) {
                Row row = sheet.createRow(rowIndex++);
                row.createCell(0).setCellValue(user.username());
                row.createCell(1).setCellValue(user.displayName());
                row.createCell(2).setCellValue(user.email() == null ? "" : user.email());
                row.createCell(3).setCellValue(user.status());
                row.createCell(4).setCellValue("");
                row.createCell(5).setCellValue("");
            }
            for (int index = 0; index < headers.size(); index++) {
                sheet.setColumnWidth(index, index == 4 ? 9_000 : 5_000);
            }
            workbook.write(output);
            workbook.dispose();
            return output.toByteArray();
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "生成用户表格失败", "api.user.workbook.generateFailed");
        }
    }

    /** 解析导入 Excel 的首个工作表；只做结构解析，业务校验交给上层逐行处理。 */
    public List<ImportRow> readImport(byte[] bytes) {
        try (Workbook workbook = WorkbookFactory.create(new ByteArrayInputStream(bytes))) {
            Sheet sheet = workbook.getNumberOfSheets() == 0 ? null : workbook.getSheetAt(0);
            if (sheet == null || sheet.getLastRowNum() < 1) {
                return List.of();
            }
            if (sheet.getLastRowNum() > MAX_ROWS) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "单次最多导入 5000 行", "api.user.import.tooManyRows");
            }
            DataFormatter formatter = new DataFormatter();
            validateHeaders(sheet.getRow(0), formatter);
            List<ImportRow> rows = new ArrayList<>();
            for (int rowIndex = 1; rowIndex <= sheet.getLastRowNum(); rowIndex++) {
                Row row = sheet.getRow(rowIndex);
                if (row == null || blank(row, formatter)) continue;
                rows.add(new ImportRow(
                        rowIndex + 1,
                        value(row, 0, formatter),
                        value(row, 1, formatter),
                        value(row, 2, formatter),
                        value(row, 3, formatter),
                        value(row, 4, formatter),
                        value(row, 5, formatter)));
            }
            return rows;
        } catch (ApiException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "无法读取 Excel，请使用平台模板", "api.user.import.invalidWorkbook");
        }
    }

    private static void validateHeaders(Row header, DataFormatter formatter) {
        List<String> actual = new ArrayList<>(ZH_HEADERS.size());
        for (int index = 0; index < ZH_HEADERS.size(); index++) {
            actual.add(header == null ? "" : value(header, index, formatter));
        }
        if (!actual.equals(ZH_HEADERS) && !actual.equals(EN_HEADERS)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Excel 表头不匹配，请使用平台模板", "api.user.import.invalidWorkbook");
        }
    }

    private static boolean blank(Row row, DataFormatter formatter) {
        for (int index = 0; index < ZH_HEADERS.size(); index++) {
            if (!value(row, index, formatter).isBlank()) return false;
        }
        return true;
    }

    private static String value(Row row, int index, DataFormatter formatter) {
        Cell cell = row.getCell(index);
        if (cell == null || cell.getCellType() == CellType.BLANK) return "";
        return formatter.formatCellValue(cell).trim();
    }

    public record ImportRow(
            int rowNumber,
            String username,
            String displayName,
            String email,
            String status,
            String departmentCodes,
            String password) {}
}
