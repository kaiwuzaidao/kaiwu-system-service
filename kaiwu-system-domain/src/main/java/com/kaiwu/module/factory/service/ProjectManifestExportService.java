package com.kaiwu.module.factory.service;

import com.kaiwu.module.factory.vo.ProjectManifestExportView;
import com.kaiwu.starter.KaiwuContext;

/**
 * 项目配置移交包导出（ADR 0042）。
 *
 * <p>只读：把项目作用域内的字典、参数配置、菜单、自定义角色及其授权导出为全量快照，
 * 不改变任何数据，也不导出数据库 ID、成员、敏感配置。</p>
 */
public interface ProjectManifestExportService {

    /**
     * 导出移交包；调用者必须是该项目的有效项目管理员。
     *
     * @param projectId  项目 ID
     * @param actor      调用者
     * @param sourceHost 导出请求到达的主机名，写入来源信息供人核对，可为空
     */
    ProjectManifestExportView export(String projectId, KaiwuContext actor, String sourceHost);
}
