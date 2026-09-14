package com.kaiwu.module.user.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

/**
 * 平台用户实体。
 *
 * <p>{@code passwordHash} 标注 {@link TableField#select()} 为 {@code false}：
 * 迁移前靠每个查询手写列白名单把密码哈希挡在外面（{@code VIEW_COLUMNS} 常量），
 * 换成 MyBatis-Plus 后 {@code selectById} / {@code selectList} 默认查全列，
 * 白名单这道保护会消失。用 {@code select = false} 让「默认查不到密码」变成实体自带的属性，
 * 而不是依赖每个调用点记得排除。</p>
 *
 * <p>登录校验确实需要密码哈希，那条路径由 {@code AuthRepository} 用显式 SQL 单独取，
 * 不走本实体的默认查询——需要密码的地方应该少且显眼。</p>
 */
@TableName("sys_user")
public class UserEntity {

    /** 主键，19 位，对外 JSON 契约中始终是字符串 */
    @TableId(type = IdType.INPUT)
    private Long id;

    /** 登录名 */
    private String username;

    /** 密码哈希，默认不参与查询 */
    @TableField(select = false)
    private String passwordHash;

    /** 显示名 */
    private String displayName;

    /** 邮箱 */
    private String email;

    /** 状态：ENABLED / DISABLED */
    private String status;

    /** 界面语言 */
    private String locale;

    /** 1 = 登录后必须先改密码 */
    private Boolean mustChangePassword;

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

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public void setPasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }

    public String getDisplayName() {
        return displayName;
    }

    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getLocale() {
        return locale;
    }

    public void setLocale(String locale) {
        this.locale = locale;
    }

    public Boolean getMustChangePassword() {
        return mustChangePassword;
    }

    public void setMustChangePassword(Boolean mustChangePassword) {
        this.mustChangePassword = mustChangePassword;
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
