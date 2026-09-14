-- 业务项目的服务地址：Gateway PROJECT 路由的上游。
--
-- 为什么不复用 backend_url：那一列是**浏览器打开的后台入口链接**
-- （前端 window.location.assign / <a target="_blank"> 直接用它跳转），
-- 与"服务端到服务端的上游地址"是两回事。同一列承担两种语义，
-- 迟早会出现"点进后台"跳到内网 API、或者路由指向一个前端页面。
--
-- 取值形态由部署形态决定，平台不做假设：
--   http://kaiwu-order-center-service:8080  K8s Service DNS / Compose 容器名
--   http://10.0.0.5:8080                    单实例固定地址
--   lb://kaiwu-order-center-service         Nacos 注册 + 客户端负载均衡
ALTER TABLE sys_project
    ADD COLUMN service_url VARCHAR(512) NULL COMMENT 'Gateway PROJECT 路由上游地址' AFTER backend_label;

-- 服务地址字段的界面文案。新增 seed 使用 92 段 ID（见 sql/increment/README.md 的分段约定）。
INSERT IGNORE INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code,
     public_visible, required_resource, status, description, version,
     created_at, updated_at)
VALUES
    (9200000000000004001, 'projects.serviceUrl', '服务地址', JSON_OBJECT('en-US', 'Service URL', 'ja-JP', 'サービス URL'), 'projects', 0, 1, 'ENABLED', 'Gateway PROJECT 路由上游', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004010, 'projects.gatewayRoute', '网关路由', JSON_OBJECT('en-US', 'Gateway route', 'ja-JP', 'ゲートウェイルート'), 'projects', 0, 1, 'ENABLED', '查看该项目的显式路由片段', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004011, 'projects.gatewayRoute.hint', '把下面的片段放进受管 Gateway 配置的 routes 下。服务注册不等于对外发布，没有这段显式路由的服务不能从外部访问。', JSON_OBJECT('en-US', 'Add the snippet below to the routes of the managed Gateway config. Registering a service does not publish it; without an explicit route it stays unreachable from outside.', 'ja-JP', '以下の断片を管理対象 Gateway 設定の routes に追加してください。'), 'projects', 0, 1, 'ENABLED', '路由片段说明', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004012, 'projects.gatewayRoute.copy', '复制片段', JSON_OBJECT('en-US', 'Copy snippet', 'ja-JP', '断片をコピー'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004013, 'projects.gatewayRoute.copied', '已复制到剪贴板', JSON_OBJECT('en-US', 'Copied to clipboard', 'ja-JP', 'クリップボードにコピーしました'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004014, 'projects.gatewayRoute.copyFailed', '复制失败，请手动选中复制', JSON_OBJECT('en-US', 'Copy failed, please select and copy manually', 'ja-JP', 'コピーに失敗しました'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004003, 'api.project.serviceUrlRequired', '请先登记项目的服务地址', JSON_OBJECT('en-US', 'Register the project service URL first', 'ja-JP', '先にサービス URL を登録してください'), 'api', 0, 1, 'ENABLED', '生成 Gateway 路由前置校验', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004002, 'projects.serviceUrlHelp', '按部署形态填写：K8s/Compose 用服务名，单实例用 http://主机:端口，Nacos 用 lb://服务名', JSON_OBJECT('en-US', 'Depends on deployment: service DNS for K8s/Compose, http://host:port for a single instance, lb://name for Nacos', 'ja-JP', 'デプロイ形態に応じて入力してください'), 'projects', 0, 1, 'ENABLED', '服务地址填写说明', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
