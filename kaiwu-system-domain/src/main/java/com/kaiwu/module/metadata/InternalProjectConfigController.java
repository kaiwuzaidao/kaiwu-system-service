package com.kaiwu.module.metadata;

import com.kaiwu.common.Result;
import com.kaiwu.module.credential.ProjectServiceCredential;
import com.kaiwu.module.credential.ProjectServiceCredentials;
import com.kaiwu.module.metadata.vo.EffectiveConfigView;
import java.util.List;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 业务服务后台线程读取本项目生效配置。
 *
 * <p>与 `/api/current/projects/{id}/configs` 的区别是身份来源：那条是浏览器里的用户，
 * 有 Gateway Context；这条是业务服务自身，只有项目服务凭据。项目由凭据决定，不接受调用方
 * 传入 projectId，避免凭据被用来读别的项目。</p>
 *
 * <p>调用方必须在内存缓存结果并定期刷新，不得在每个业务请求里同步调用本接口——那会让
 * 平台可用性成为业务请求的前置依赖。</p>
 */
@RestController
@RequestMapping("/api/internal/configs")
public class InternalProjectConfigController {

    private final MetadataService service;
    private final ProjectServiceCredentials credentials;

    public InternalProjectConfigController(MetadataService service, ProjectServiceCredentials credentials) {
        this.service = service;
        this.credentials = credentials;
    }

    /**
     * 下发**已按语言解析的文本**，不下发 i18n key（ADR 0013）。
     *
     * <p>Starter 的 ProjectConfigClient 读的是业务进程内的内存快照，够不到平台目录，
     * 下发 key 会让业务后端拿到一个自己翻译不了的值。</p>
     */
    @GetMapping
    public Result<List<EffectiveConfigView>> effectiveConfigs(
            @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
            @RequestHeader(name = "Accept-Language", required = false) String language) {
        ProjectServiceCredential credential = credentials.authenticateBearer(authorization);
        return Result.ok(service.effectiveConfigsOfProject(credential.projectId(), language, false));
    }
}
