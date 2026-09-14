package com.kaiwu.module.metadata.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

/** 字典类型实体。 */
@TableName("sys_dict_type")
public class DictTypeEntity {

    @TableId(type = IdType.INPUT)
    private Long id;

    /** 作用域：0 为平台全局，其余为项目 ID */
    private Long scopeId;

    /** 字典编码 */
    private String dictCode;

    /** 字典名称 */
    private String dictName;

    /** 引用的国际化资源 key；非空即启用（ADR 0014） */
    private String dictNameKey;

    /** 是否继承全局同名字典 */
    private Boolean inheritGlobal;

    /** 显示顺序；越小越靠前，由管理端拖拽维护 */
    private Integer sortNo;

    /** 状态 */
    private String status;

    /** 描述 */
    private String description;

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

    public Long getScopeId() {
        return scopeId;
    }

    public void setScopeId(Long scopeId) {
        this.scopeId = scopeId;
    }

    public String getDictCode() {
        return dictCode;
    }

    public void setDictCode(String dictCode) {
        this.dictCode = dictCode;
    }

    public String getDictName() {
        return dictName;
    }

    public void setDictName(String dictName) {
        this.dictName = dictName;
    }

    public String getDictNameKey() {
        return dictNameKey;
    }

    public void setDictNameKey(String dictNameKey) {
        this.dictNameKey = dictNameKey;
    }

    public Boolean getInheritGlobal() {
        return inheritGlobal;
    }

    public void setInheritGlobal(Boolean inheritGlobal) {
        this.inheritGlobal = inheritGlobal;
    }

    public Integer getSortNo() {
        return sortNo;
    }

    public void setSortNo(Integer sortNo) {
        this.sortNo = sortNo;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
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
