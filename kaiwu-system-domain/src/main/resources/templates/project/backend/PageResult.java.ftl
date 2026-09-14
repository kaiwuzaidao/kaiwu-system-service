package ${basePackage}.common;

import java.util.List;

public record PageResult<T>(
        long current,
        long size,
        long total,
        List<T> records
) {
}
