package com.kaiwu.module.org.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

/**
 * 用户与部门的关联行（{@code sys_user_department}）。
 *
 * <p>**有意不标 {@code @TableId}**：这张表的主键是 {@code (user_id, department_id)} 复合键，
 * 标在任何单列上都是假话，将来有人调 {@code selectById} 会拿到一行本不该唯一的数据。
 * 没有 {@code @TableId} 时 {@code selectById} / {@code updateById} 不可用，而
 * {@code selectList(wrapper)} 正常——正好只暴露这张表该有的用法。</p>
 */
@TableName("sys_user_department")
public class UserDepartmentEntity {

    private Long userId;
    private Long departmentId;
    /** 1 = 主部门 */
    private Boolean primaryDepartment;

    private LocalDateTime createdAt;

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public Long getDepartmentId() {
        return departmentId;
    }

    public void setDepartmentId(Long departmentId) {
        this.departmentId = departmentId;
    }

    public Boolean getPrimaryDepartment() {
        return primaryDepartment;
    }

    public void setPrimaryDepartment(Boolean primaryDepartment) {
        this.primaryDepartment = primaryDepartment;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
