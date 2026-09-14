package com.kaiwu.common;

import org.springframework.http.HttpStatus;

/**
 * 分页参数的统一边界（约束 {@code query.bounded-result}）。
 *
 * <p>任何接受外部分页参数的查询都必须先经过本类。原因是结果集会整体驻留内存后再序列化，
 * 一个未设上限的 {@code size} 等于允许调用方要求全表，与导出上限是同一类 OOM。</p>
 *
 * <p>超限一律拒绝而不是静默截断：截断会让调用方以为自己拿到了全量，
 * 少数据比报错更难被发现。</p>
 */
public final class PageBounds {

    /** 单页最大行数；前端所有列表页的 pageSize 均不超过该值。 */
    public static final long MAX_SIZE = 100;

    private PageBounds() {}

    /**
     * 校验外部传入的分页参数。
     *
     * @param current 页码，从 1 开始
     * @param size    单页行数，取值 [1, {@link #MAX_SIZE}]
     * @throws ApiException 参数越界时抛出 HTTP 400，不做任何截断
     */
    public static void require(long current, long size) {
        if (current < 1) {
            throw outOfRange();
        }
        requireSize(size);
    }

    /**
     * 只校验行数上限，供按 {@code offset/size} 而非页码分页的查询使用。
     *
     * <p>Service 已经校验过的路径，Repository 仍会再调一次：多一次整数比较的代价可以忽略，
     * 换来的是「出口处必然有界」——{@code BoundedQueryConventionTest} 因此能在文件级别
     * 精确断言，而不是只能按模块粗判。</p>
     *
     * @param size 单页行数，取值 [1, {@link #MAX_SIZE}]
     * @throws ApiException 越界时抛出 HTTP 400
     */
    public static void requireSize(long size) {
        if (size < 1 || size > MAX_SIZE) {
            throw outOfRange();
        }
    }

    private static ApiException outOfRange() {
        return new ApiException(HttpStatus.BAD_REQUEST, "分页参数超出允许范围", "api.pagination.invalid");
    }
}
