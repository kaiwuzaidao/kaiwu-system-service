server:
  port: ${r"${SERVER_PORT:8080}"}

spring:
  application:
    name: kaiwu-${projectCode}-service
  datasource:
    url: jdbc:mysql://${r"${DB_HOST:127.0.0.1}"}:${r"${DB_PORT:3306}"}/${r"${DB_NAME:kaiwu_"}${normalizedProjectCode}}?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai
    username: ${r"${DB_USER}"}
    password: ${r"${DB_PASSWORD}"}
    driver-class-name: com.mysql.cj.jdbc.Driver
  flyway:
    enabled: true
    locations: classpath:db/migration
    default-schema: ${r"${DB_NAME:kaiwu_"}${normalizedProjectCode}}
    table: flyway_schema_history
    # 生成项目从 V1 初始化全新空库，不接管已有 schema。
    baseline-on-migrate: false

mybatis-plus:
  # 单表 CRUD 使用 BaseMapper；复杂 JOIN、动态条件与报表查询优先放 mapper XML。
  mapper-locations: classpath*:/mapper/**/*.xml

management:
  endpoints:
    web:
      exposure:
        include: health,info

kaiwu:
  starter:
    enabled: true
    context-public-key: ${r"${KAIWU_CONTEXT_PUBLIC_KEY}"}
    audience: kaiwu-${projectCode}-service
    project-code: ${projectCode}
    notification:
      # 站内信投递：只写、单向、失败即降级（ADR 0007）。
      # 两个变量任一缺失时客户端保持静默，不影响业务启动。
      system-base-url: ${r"${KAIWU_SYSTEM_SERVICE_URI:}"}
      delivery-token: ${r"${KAIWU_NOTIFICATION_DELIVERY_TOKEN:}"}
    scheduler:
      # 调度配置由 Kaiwu System 统一管理；任务只在当前项目服务内执行。
      # 凭据仅通过运行环境注入，项目仓库和配置中心都不要保存明文。
      enabled: ${r"${KAIWU_SCHEDULER_ENABLED:false}"}
      system-base-url: ${r"${KAIWU_SYSTEM_SERVICE_URI:}"}
      project-id: ${projectId}
      credential: ${r"${KAIWU_SCHEDULER_CREDENTIAL:}"}
      instance-id: ${r"${KAIWU_SCHEDULER_INSTANCE_ID:${HOSTNAME:local}}"}
      sync-interval-seconds: ${r"${KAIWU_SCHEDULER_SYNC_INTERVAL_SECONDS:30}"}
      pool-size: ${r"${KAIWU_SCHEDULER_POOL_SIZE:2}"}
    config:
      # 平台参数配置读取：内存快照 + 后台刷新，请求路径上不发网络请求。
      # 与调度共用同一项目服务凭据，留空即自动复用上面的 scheduler 配置。
      enabled: ${r"${KAIWU_PROJECT_CONFIG_ENABLED:true}"}
      refresh-seconds: ${r"${KAIWU_PROJECT_CONFIG_REFRESH_SECONDS:300}"}
    include-paths:
      - /api/**
    exclude-paths:
      - /actuator/health
      - /actuator/health/**
