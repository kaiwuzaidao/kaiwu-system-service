package com.kaiwu.module.connector.vo;

import java.time.LocalDateTime;

/**
 * 存储账号连通性测试结果。
 *
 * @param success 是否成功
 * @param latencyMs 总耗时（毫秒）
 * @param message 可直接展示的结果说明，不含密钥
 * @param testedAt 测试时间
 */
public record StorageConnectionTestView(boolean success, long latencyMs, String message, LocalDateTime testedAt) {}
