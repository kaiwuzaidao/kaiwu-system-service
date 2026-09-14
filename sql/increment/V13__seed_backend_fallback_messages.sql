-- 所有跨服务异常必须携带稳定 messageKey；详细中文仅作为兼容信息和审计事实。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000000901, 'api.common.badRequest', '请求参数错误', JSON_OBJECT('en-US', 'Invalid request parameters'), 'api', 0, 1, 'ENABLED', '未细分的参数校验安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000902, 'api.common.notFound', '请求的资源不存在', JSON_OBJECT('en-US', 'The requested resource was not found'), 'api', 0, 1, 'ENABLED', '未细分的资源不存在安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000903, 'api.common.conflict', '当前操作与资源状态冲突', JSON_OBJECT('en-US', 'The operation conflicts with the current resource state'), 'api', 0, 1, 'ENABLED', '未细分的状态冲突安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000904, 'api.common.internalError', '服务处理失败，请稍后重试', JSON_OBJECT('en-US', 'The service could not process the request. Try again later.'), 'api', 0, 1, 'ENABLED', '内部错误安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000905, 'api.common.unauthorized', '未登录或登录已过期', JSON_OBJECT('en-US', 'Sign-in is required or has expired'), 'api', 0, 1, 'ENABLED', '认证失败安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000906, 'api.common.upstreamFailed', '上游服务响应异常', JSON_OBJECT('en-US', 'An upstream service returned an invalid response'), 'api', 0, 1, 'ENABLED', '上游错误安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000907, 'api.common.serviceUnavailable', '服务暂时不可用，请稍后重试', JSON_OBJECT('en-US', 'The service is temporarily unavailable. Try again later.'), 'api', 0, 1, 'ENABLED', '服务不可用安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000908, 'api.common.forbidden', '无操作权限', JSON_OBJECT('en-US', 'You do not have permission for this operation'), 'api', 0, 1, 'ENABLED', '授权失败安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000909, 'api.common.operationFailed', '操作失败，请稍后重试', JSON_OBJECT('en-US', 'The operation failed. Try again later.'), 'api', 0, 1, 'ENABLED', '未知业务错误安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
