package com.kaiwu.module.operation.entity;

import java.time.LocalDateTime;

/** 调度凭据行。 */
public class SchedulerCredentialRow {

    private String id;
    private String projectId;
    private String tokenHash;
    private String status;
    private String serviceCode;
    private LocalDateTime expiresAt;
    private LocalDateTime lastUsedAt;
    private LocalDateTime createdAt;

    /** 读取凭据字符串ID，用于认证定位而非授予权限。 */
    public String getId() {
        return id;
    }

    /** 保存Mapper读取的凭据ID，不接收浏览器主体身份。 */
    public void setId(String id) {
        this.id = id;
    }

    /** 读取凭据绑定的权威项目ID。 */
    public String getProjectId() {
        return projectId;
    }

    /** 映射持久化项目归属，认证不得用请求项目覆盖。 */
    public void setProjectId(String projectId) {
        this.projectId = projectId;
    }

    /** 仅供认证比较的BCrypt哈希，不得输出为管理元数据。 */
    public String getTokenHash() {
        return tokenHash;
    }

    /** 接收已持久化哈希，不存放一次性明文令牌。 */
    public void setTokenHash(String tokenHash) {
        this.tokenHash = tokenHash;
    }

    /** 区分旧default与显式服务，防止scope凭据继承旧入口权限。 */
    public String getServiceCode() {
        return serviceCode;
    }

    /** 映射签发时固定的服务编码，不由认证请求改写。 */
    public void setServiceCode(String serviceCode) {
        this.serviceCode = serviceCode;
    }

    /** 读取以UTC约定保存的有限期限，旧default允许空值。 */
    public LocalDateTime getExpiresAt() {
        return expiresAt;
    }

    /** 映射UTC到期时刻，认证比较不得随数据库会话时区变化。 */
    public void setExpiresAt(LocalDateTime value) {
        expiresAt = value;
    }

    /** 读取限频统计的UTC最近认证时间，不作为授权事实。 */
    public LocalDateTime getLastUsedAt() {
        return lastUsedAt;
    }

    /** 映射使用统计时间，统计更新失败不能使认证异常。 */
    public void setLastUsedAt(LocalDateTime value) {
        lastUsedAt = value;
    }

    /** 读取数据库生成的创建元数据，列表不返回凭据哈希。 */
    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    /** 保存创建时间映射，不改变凭据有效期限。 */
    public void setCreatedAt(LocalDateTime value) {
        createdAt = value;
    }

    /** 读取ACTIVE或REVOKED状态，撤销记录仍须保留。 */
    public String getStatus() {
        return status;
    }

    /** 映射凭据状态，不隐式删除撤销墓碑。 */
    public void setStatus(String status) {
        this.status = status;
    }
}
