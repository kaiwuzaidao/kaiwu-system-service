package ${basePackage}.common;

import java.util.List;

/** 封装受分页上限约束的列表查询结果。 */
public record PageResult<T>(
        long current,
        long size,
        long total,
        List<T> records
) {
}
