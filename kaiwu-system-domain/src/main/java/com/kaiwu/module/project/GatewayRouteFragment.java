package com.kaiwu.module.project;

import com.kaiwu.module.project.vo.ProjectView;

/**
 * 按项目生成 Gateway 的显式 PROJECT 路由片段。
 *
 * <p>路由的每一项都从平台已有事实推导，不需要人工编造：前缀、audience、projectCode
 * 由 {@code projectCode} 决定，上游地址取项目登记的 {@code serviceUrl}。
 * 这样"哪些服务能被外部访问"仍然由平台决定（ARCHITECTURE §7），
 * 而运维只需要把生成好的片段放进受管配置，不必自己拼 metadata——
 * 手写 metadata 漏掉 {@code accessMode} 会让 PROJECT 路由退化成没有项目绑定的路由。</p>
 *
 * <p>本类只生成文本，**不写任何配置中心**。自动写入 Gateway 的 Data ID 是对
 * "控制全部路由的单份配置"做读-改-写：并发写会互相覆盖，写坏一次就是整个网关不可用。
 * 那一步需要先有 ADR 明确并发与回滚策略。</p>
 */
public final class GatewayRouteFragment {

    private GatewayRouteFragment() {}

    /**
     * @param project 已登记 {@code serviceUrl} 的项目
     * @return 可直接粘贴进 Gateway routes 的 YAML 片段
     */
    public static String render(ProjectView project) {
        String code = project.projectCode();
        String uri = project.serviceUrl();
        return """
                # %s（%s）的显式 PROJECT 路由。
                # 放进受管 Gateway 配置的 routes 下；服务注册到注册中心不等于对外发布，
                # 没有这段显式 route 的服务不能从外部访问。
                - id: %s-project
                  uri: %s
                  predicates:
                    - Path=/%s-api/**
                  filters:
                    - RewritePath=/%s-api/(?<segment>.*), /${segment}
                  metadata:
                    accessMode: PROJECT
                    audience: kaiwu-%s-service
                    projectCode: %s
                """
                .formatted(project.projectName(), code, code, uri, code, code, code, code);
    }
}
