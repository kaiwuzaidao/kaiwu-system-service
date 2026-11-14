package com.kaiwu.module.project.vo;

import java.util.List;

/** 可由管理员审核的各服务路由片段。 */
public record GatewayRoutesView(List<Fragment> fragments) {
    /** 一个启用服务对应的完整路由 YAML。 */
    public record Fragment(String serviceCode, String fragment) {}
}
