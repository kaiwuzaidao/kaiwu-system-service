package com.kaiwu.module.i18n;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.kaiwu.common.ApiException;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * 导出再导入必须能原样还原，否则离线翻译这条路走不通。
 */
class I18nTranslationWorkbookCodecTest {

    private final I18nTranslationWorkbookCodec codec = new I18nTranslationWorkbookCodec();

    @Test
    void exportedWorkbookCanBeParsedBack() {
        byte[] workbook = codec.export(
                "ja-JP",
                Map.of(
                        I18nTranslationWorkbookCodec.SHEET_RESOURCE,
                        List.of(
                                new I18nTranslationWorkbookCodec.TranslationRow("common.save", "保存", "保存する", "通用操作"),
                                // 未翻译行：导出时译文列为空
                                new I18nTranslationWorkbookCodec.TranslationRow("common.cancel", "取消", null, null))));

        Map<String, List<I18nTranslationWorkbookCodec.ImportedTranslation>> parsed = codec.parse(workbook);

        assertThat(parsed).containsKey(I18nTranslationWorkbookCodec.SHEET_RESOURCE);
        List<I18nTranslationWorkbookCodec.ImportedTranslation> rows =
                parsed.get(I18nTranslationWorkbookCodec.SHEET_RESOURCE);
        // 只回收已填译文的行：空译文若按空串写入，覆盖率校验会误判为已翻译。
        assertThat(rows).hasSize(1);
        assertThat(rows.getFirst().key()).isEqualTo("common.save");
        assertThat(rows.getFirst().translation()).isEqualTo("保存する");
        // 行号要能定位回用户的文件（表头占第 1 行，首条数据是第 2 行）。
        assertThat(rows.getFirst().rowNumber()).isEqualTo(2);
    }

    @Test
    void parseKeepsSheetsSeparateSoEachKindUpdatesItsOwnTable() {
        byte[] workbook = codec.export(
                "ja-JP",
                Map.of(
                        I18nTranslationWorkbookCodec.SHEET_RESOURCE,
                                List.of(new I18nTranslationWorkbookCodec.TranslationRow(
                                        "common.save", "保存", "保存する", null)),
                        I18nTranslationWorkbookCodec.SHEET_MENU,
                                List.of(new I18nTranslationWorkbookCodec.TranslationRow(
                                        "/users", "用户管理", "ユーザー管理", null)),
                        I18nTranslationWorkbookCodec.SHEET_DICT,
                                List.of(new I18nTranslationWorkbookCodec.TranslationRow(
                                        "user.status:ENABLED", "启用", "有効", null))));

        Map<String, List<I18nTranslationWorkbookCodec.ImportedTranslation>> parsed = codec.parse(workbook);

        assertThat(parsed)
                .containsOnlyKeys(
                        I18nTranslationWorkbookCodec.SHEET_RESOURCE,
                        I18nTranslationWorkbookCodec.SHEET_MENU,
                        I18nTranslationWorkbookCodec.SHEET_DICT);
        assertThat(parsed.get(I18nTranslationWorkbookCodec.SHEET_MENU)
                        .getFirst()
                        .key())
                .isEqualTo("/users");
        assertThat(parsed.get(I18nTranslationWorkbookCodec.SHEET_DICT)
                        .getFirst()
                        .key())
                .isEqualTo("user.status:ENABLED");
    }

    @Test
    void rejectsEmptyOrUnrecognizableFile() {
        assertThatThrownBy(() -> codec.parse(new byte[0]))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("文件大小");

        assertThatThrownBy(() -> codec.parse("not an excel".getBytes()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("无法解析");
    }

    @Test
    void rejectsWorkbookWithoutKnownSheets() {
        // 用户可能自己新建一个表就导入；没有约定 sheet 名时必须明确报错，
        // 而不是静默导入 0 条让人以为成功了。
        byte[] workbook = codec.export("ja-JP", Map.of("unknown", List.of()));

        assertThatThrownBy(() -> codec.parse(workbook))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("没有可识别的工作表");
    }
}
