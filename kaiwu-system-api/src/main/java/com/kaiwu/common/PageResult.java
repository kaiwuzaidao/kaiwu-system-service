package com.kaiwu.common;

import java.util.List;

/**
 * 统一分页响应，Long ID 由具体视图类型序列化为字符串。
 */
public record PageResult<T>(long current, long size, long total, List<T> records) {}
