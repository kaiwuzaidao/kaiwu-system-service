package com.kaiwu.module.i18n.entity;

/** 译文导出行；三个 sheet 共用同一形状。 */
public class TranslationExportJoinRow {

    private String exportKey;
    private String defaultText;
    private String translation;
    private String note;

    public String getExportKey() {
        return exportKey;
    }

    public void setExportKey(String exportKey) {
        this.exportKey = exportKey;
    }

    public String getDefaultText() {
        return defaultText;
    }

    public void setDefaultText(String defaultText) {
        this.defaultText = defaultText;
    }

    public String getTranslation() {
        return translation;
    }

    public void setTranslation(String translation) {
        this.translation = translation;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }
}
