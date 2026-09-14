# 把本文件复制到 kaiwu-gateway-service/routes.local.d/${projectCode}.yml 即可生效，
# 不需要改 application-local.yml。Gateway 只在 local profile 加载该目录，
# 路由仍是逐条显式声明，不是服务发现。
- id: ${projectCode}-project-local
  uri: http://127.0.0.1:${r"${SERVER_PORT:-"}${localServerPort}}
  predicates:
    - Path=/${projectCode}-api/**
  filters:
    - RewritePath=/${projectCode}-api/(?<segment>.*), /${r"${segment}"}
  metadata:
    accessMode: PROJECT
    audience: kaiwu-${projectCode}-service
    projectCode: ${projectCode}
