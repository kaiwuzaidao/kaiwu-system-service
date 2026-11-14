package com.kaiwu.module.project.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.vo.BackendServiceView;
import com.kaiwu.module.project.vo.GatewayRoutesView;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;

/** 项目后端服务的受控登记和路由片段生成。 */
public interface ProjectBackendService {
    /** 列出目标项目服务。 */
    List<BackendServiceView> list(String projectId, KaiwuContext actor);
    /** 登记非默认服务。 */
    BackendServiceView create(String projectId, String code, String url, KaiwuContext actor, RequestMetadata metadata);
    /** 修改已登记服务地址。 */
    BackendServiceView updateUrl(
            String projectId, String code, String url, KaiwuContext actor, RequestMetadata metadata);
    /** 启用或停用已登记服务。 */
    BackendServiceView updateStatus(
            String projectId, String code, String status, KaiwuContext actor, RequestMetadata metadata);
    /** 返回所有可发布服务的受管 YAML。 */
    GatewayRoutesView routes(String projectId, KaiwuContext actor);
}
