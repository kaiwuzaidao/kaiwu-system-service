package com.kaiwu.module.i18n.entity;

/** 平台语言字典项的连接结果。 */
public class LocaleJoinRow {

    private String itemValue;
    private String itemLabel;
    private String labelI18nKey;
    private String extraJson;
    private Boolean defaultItem;

    public String getItemValue() {
        return itemValue;
    }

    public void setItemValue(String itemValue) {
        this.itemValue = itemValue;
    }

    public String getItemLabel() {
        return itemLabel;
    }

    public void setItemLabel(String itemLabel) {
        this.itemLabel = itemLabel;
    }

    public String getLabelI18nKey() {
        return labelI18nKey;
    }

    public void setLabelI18nKey(String labelI18nKey) {
        this.labelI18nKey = labelI18nKey;
    }

    public String getExtraJson() {
        return extraJson;
    }

    public void setExtraJson(String extraJson) {
        this.extraJson = extraJson;
    }

    public Boolean getDefaultItem() {
        return defaultItem;
    }

    public void setDefaultItem(Boolean defaultItem) {
        this.defaultItem = defaultItem;
    }
}
