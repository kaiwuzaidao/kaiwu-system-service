package com.kaiwu.module.metadata.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import java.util.List;

/**
 * 拖拽排序请求：按新顺序给出**该范围内的全部** ID。
 *
 * <p>要求全量而不是「把 A 移到 B 之后」的增量描述：字典类型和字典项在管理端都不分页，
 * 前端本来就持有完整列表；服务端拿到全量才能校验集合一致，从而拒掉基于过期列表的提交
 * （中途别人删了一条时，增量描述会把剩下的顺序写乱且无从发现）。</p>
 *
 * @param ids 排序后的完整 ID 列表；顺序即最终显示顺序
 */
public record SortOrderRequest(
        @NotEmpty(message = "排序列表不能为空") @Size(max = 500, message = "单次排序不能超过 500 条") List<String> ids) {}
