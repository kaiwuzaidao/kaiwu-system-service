package com.kaiwu.module.project.entity;
/** 后端服务登记查询行，不直接作为 HTTP 响应。 */
public class BackendServiceRow {
    private String serviceCode;
    private String serviceUrl;
    private String status;

    /** 读取项目内服务标识，用于稳定路径和audience推导。 */
    public String getServiceCode() {
        return serviceCode;
    }

    /** 映射数据库服务编码，查询端不能覆盖调用身份。 */
    public void setServiceCode(String serviceCode) {
        this.serviceCode = serviceCode;
    }

    /** 读取管理员登记的目标原点，不含服务凭据。 */
    public String getServiceUrl() {
        return serviceUrl;
    }

    /** 映射可清空的服务地址，default与旧项目字段需同事务同步。 */
    public void setServiceUrl(String serviceUrl) {
        this.serviceUrl = serviceUrl;
    }

    /** 读取服务的后续可发布状态，不代表已发布路由已撤销。 */
    public String getStatus() {
        return status;
    }

    /** 保存启停事实，不隐式删除登记或部署中的配置。 */
    public void setStatus(String status) {
        this.status = status;
    }
}
