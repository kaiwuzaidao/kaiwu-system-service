package com.kaiwu.module.connector.controller;

import com.kaiwu.common.Result;
import com.kaiwu.module.connector.service.StorageCredentialService;
import com.kaiwu.module.connector.vo.StorageCredentialBundleView;
import com.kaiwu.module.project.model.ProjectServiceCredential;
import com.kaiwu.module.project.service.ProjectServiceCredentials;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 业务服务后台线程申请对象存储临时凭证（ADR 0039 第 2 节）。
 *
 * <p>身份只来自项目服务凭据，项目由凭据决定，不接受调用方传入 projectId。路径位于
 * {@code /api/internal}，由网关阻断外部访问。调用方必须缓存结果并在后台续签，
 * 不得在业务请求里同步调用本接口。
 */
@RestController
@RequestMapping("/api/internal/storage")
public class InternalStorageCredentialController {

    private final StorageCredentialService service;
    private final ProjectServiceCredentials credentials;

    /**
     * 创建内部接口。
     *
     * @param service 签发服务
     * @param credentials 项目服务凭据校验
     */
    public InternalStorageCredentialController(
            StorageCredentialService service, ProjectServiceCredentials credentials) {
        this.service = service;
        this.credentials = credentials;
    }

    /**
     * 签发本项目全部可用绑定的临时凭证。响应禁止任何缓存。
     *
     * @param authorization {@code Bearer} 项目服务凭据
     * @return 凭证集合
     */
    @PostMapping("/credentials")
    public ResponseEntity<Result<StorageCredentialBundleView>> issue(
            @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization) {
        ProjectServiceCredential credential = credentials.authenticateBearer(authorization);
        return ResponseEntity.ok()
                .cacheControl(CacheControl.noStore())
                .body(Result.ok(service.issue(credential.projectId())));
    }
}
