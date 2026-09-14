package com.kaiwu.module.system.controller;

import com.kaiwu.common.Result;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 登录鉴权纵切的最小受保护平台接口。
 */
@RestController
@RequestMapping("/api/platform")
public class PlatformProbeController {

    /** 鉴权探针：返回当前上下文与命中的权限码，用于验证 Gateway Context 是否生效。 */
    @GetMapping("/probe")
    @RequirePermission("system:platform:read")
    public Result<Map<String, String>> probe() {
        return Result.ok(Map.of(
                "status", "AUTHORIZED",
                "userId", StarterContext.require().userId(),
                "permission", "system:platform:read"));
    }
}
