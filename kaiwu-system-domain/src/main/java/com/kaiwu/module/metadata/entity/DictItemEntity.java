package com.kaiwu.module.metadata.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

/**
 * 字典项实体。
 *
 * <p>{@code label_i18n} 列由 ADR 0015 退役：多语言只走 {@code labelI18nKey} 引用资源。
 * 该列仍映射进实体，是因为编辑时必须把它显式写成 null——存量库里可能还有值，
 * 不写就会留下一个永远读不到却仍在数据库里的旧译文。</p>
 */
@TableName("sys_dict_item")
public class DictItemEntity {

    @TableId(type = IdType.INPUT)
    private Long id;

    /** 所属字典类型 */
    private Long dictTypeId;

    /** 标签原文 */
    private String itemLabel;

    /** 值 */
    private String itemValue;

    /** 排序 */
    private Integer sortNo;

    /** 是否默认项 */
    private Boolean defaultItem;

    /** 标签颜色 */
    private String color;

    /** 扩展 JSON */
    private String extraJson;

    /** 已退役的内联多语言列（ADR 0015），只写 null */
    private String labelI18n;

    /** 引用的国际化资源 key；非空即启用（ADR 0014） */
    private String labelI18nKey;

    /** 状态 */
    private String status;

    /** 创建时间 */
    private LocalDateTime createdAt;

    /** 更新时间 */
    private LocalDateTime updatedAt;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getDictTypeId() {
        return dictTypeId;
    }

    public void setDictTypeId(Long dictTypeId) {
        this.dictTypeId = dictTypeId;
    }

    public String getItemLabel() {
        return itemLabel;
    }

    public void setItemLabel(String itemLabel) {
        this.itemLabel = itemLabel;
    }

    public String getItemValue() {
        return itemValue;
    }

    public void setItemValue(String itemValue) {
        this.itemValue = itemValue;
    }

    public Integer getSortNo() {
        return sortNo;
    }

    public void setSortNo(Integer sortNo) {
        this.sortNo = sortNo;
    }

    public Boolean getDefaultItem() {
        return defaultItem;
    }

    public void setDefaultItem(Boolean defaultItem) {
        this.defaultItem = defaultItem;
    }

    public String getColor() {
        return color;
    }

    public void setColor(String color) {
        this.color = color;
    }

    public String getExtraJson() {
        return extraJson;
    }

    public void setExtraJson(String extraJson) {
        this.extraJson = extraJson;
    }

    public String getLabelI18n() {
        return labelI18n;
    }

    public void setLabelI18n(String labelI18n) {
        this.labelI18n = labelI18n;
    }

    public String getLabelI18nKey() {
        return labelI18nKey;
    }

    public void setLabelI18nKey(String labelI18nKey) {
        this.labelI18nKey = labelI18nKey;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}
