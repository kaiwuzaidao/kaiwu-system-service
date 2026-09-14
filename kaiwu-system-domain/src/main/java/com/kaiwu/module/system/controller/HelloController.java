package com.kaiwu.module.system.controller;

import com.kaiwu.common.Result;
import com.kaiwu.module.system.vo.HelloView;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 骨架黄金路径，仅用于验证 Web -> Gateway -> System。
 */
@RestController
@RequestMapping("/api")
public class HelloController {

    /** 最小连通性探针，不鉴权：用于确认 Gateway → System 链路本身是通的。 */
    @GetMapping("/hello")
    public Result<HelloView> hello() {
        return Result.ok(new HelloView("kaiwu-system-service", "UP", "gateway + api/domain/boot"));
    }
}
