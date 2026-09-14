package com.kaiwu.module.user;

import static org.assertj.core.api.Assertions.assertThat;

import com.kaiwu.module.user.vo.UserView;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.time.LocalDateTime;
import java.util.List;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;

class UserWorkbookCodecTest {

    @Test
    void exportsAndReadsUserWorkbookWithoutPasswordLeak() {
        UserWorkbookCodec codec = new UserWorkbookCodec();
        byte[] workbook = codec.exportUsers(List.of(new UserView(
                "1", "alice", "Alice", "alice@example.com", "ENABLED", LocalDateTime.now(), LocalDateTime.now())));

        assertThat(workbook).isNotEmpty();
        List<UserWorkbookCodec.ImportRow> rows = codec.readImport(workbook);
        assertThat(rows).hasSize(1);
        assertThat(rows.getFirst().username()).isEqualTo("alice");
        assertThat(rows.getFirst().password()).isBlank();
    }

    @Test
    void exportsEnglishHeadersAndStillReadsTheSameStableColumns() throws Exception {
        UserWorkbookCodec codec = new UserWorkbookCodec();
        byte[] workbook = codec.exportUsers(
                List.of(new UserView(
                        "1",
                        "alice",
                        "Alice",
                        "alice@example.com",
                        "ENABLED",
                        LocalDateTime.now(),
                        LocalDateTime.now())),
                "en-US");

        try (var parsed = WorkbookFactory.create(new ByteArrayInputStream(workbook))) {
            assertThat(parsed.getSheetAt(0).getSheetName()).isEqualTo("Users");
            assertThat(parsed.getSheetAt(0).getRow(0).getCell(0).getStringCellValue())
                    .isEqualTo("Username*");
        }
        assertThat(codec.readImport(workbook).getFirst().username()).isEqualTo("alice");
    }

    @Test
    void rejectsUnknownOrReorderedHeadersInsteadOfMisreadingColumns() throws Exception {
        UserWorkbookCodec codec = new UserWorkbookCodec();
        byte[] invalidWorkbook;
        try (var workbook = new XSSFWorkbook();
                var output = new ByteArrayOutputStream()) {
            var sheet = workbook.createSheet("Users");
            var header = sheet.createRow(0);
            List.of(
                            "Display name*",
                            "Username*",
                            "Email",
                            "Status",
                            "Department codes (comma-separated)",
                            "Initial password*")
                    .forEach(value -> header.createCell(header.getLastCellNum() < 0 ? 0 : header.getLastCellNum())
                            .setCellValue(value));
            sheet.createRow(1).createCell(0).setCellValue("alice");
            workbook.write(output);
            invalidWorkbook = output.toByteArray();
        }

        org.assertj.core.api.Assertions.assertThatThrownBy(() -> codec.readImport(invalidWorkbook))
                .isInstanceOf(com.kaiwu.common.ApiException.class)
                .hasMessage("Excel 表头不匹配，请使用平台模板");
    }
}
