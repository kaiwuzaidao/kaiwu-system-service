package com.kaiwu.module.connector.service;

import com.kaiwu.module.connector.dto.request.ProjectStorageBindRequest;
import com.kaiwu.module.connector.dto.request.StorageAccountSaveRequest;
import com.kaiwu.module.connector.vo.ProjectStorageBindingView;
import com.kaiwu.module.connector.vo.StorageAccountView;
import com.kaiwu.module.connector.vo.StorageConnectionTestView;
import java.util.List;

/**
 * 对象存储的管理用例（ADR 0039）：存储账号与项目绑定。只供平台管理员使用，
 * 权限由 Controller 的 {@code system:storage:*} 校验。
 */
public interface StorageService {

    /**
     * 列出存储账号。
     *
     * @return 账号视图，Secret 只以是否已配置表达
     */
    List<StorageAccountView> listAccounts();

    /**
     * 新建或修改存储账号。
     *
     * @param id 账号 ID，为空表示新建
     * @param request 账号参数；修改时 Secret 留空表示沿用原值
     * @param operatorId 操作人 ID
     * @return 保存后的账号视图
     */
    StorageAccountView saveAccount(String id, StorageAccountSaveRequest request, String operatorId);

    /**
     * 实际签发一次临时凭证并写删探测对象，结果记入账号。
     *
     * @param id 账号 ID
     * @return 测试结果，失败时也正常返回
     */
    StorageConnectionTestView testAccount(String id);

    /**
     * 列出项目存储绑定。
     *
     * @param projectId 项目 ID，为空表示全部项目
     * @return 绑定视图
     */
    List<ProjectStorageBindingView> listBindings(String projectId);

    /**
     * 把项目的存储名绑定到账号；已有生效绑定且账号不同时，旧绑定转为只读，历史文件仍可读取。
     *
     * @param request 绑定参数
     * @return 当前生效的绑定
     */
    ProjectStorageBindingView bind(ProjectStorageBindRequest request);

    /**
     * 修改绑定状态。同一项目同一存储名同时只能有一条生效绑定。
     *
     * @param id 绑定 ID
     * @param status 目标状态
     * @return 修改后的绑定
     */
    ProjectStorageBindingView changeBindingStatus(String id, String status);
}
