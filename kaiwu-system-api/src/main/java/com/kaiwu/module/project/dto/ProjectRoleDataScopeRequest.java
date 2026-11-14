package com.kaiwu.module.project.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

/**
 * 整体替换某个角色的数据范围配置。
 *
 * <p>覆盖语义：请求里没有出现的资源，其已有配置被删除，等价于回到「仅本人」。
 * 校验（范围在资源允许范围内、部门存在、数量上限）在服务端完成。</p>
 *
 * @param items 每个资源一项，资源码不得重复
 */
public record ProjectRoleDataScopeRequest(@NotNull(message = "配置列表不能为空") @Valid List<Item> items) {

    /**
     * 某个资源上的范围。
     *
     * @param resourceCode 资源码
     * @param scope        范围类型，取值见 DATA_SCOPE.md §3
     * @param includeChild 仅 {@code CUSTOM_DEPT} 有意义，是否包含所选部门的下级
     * @param deptIds      仅 {@code CUSTOM_DEPT} 使用的部门 ID，其它类型必须为空
     */
    public record Item(
            @NotBlank(message = "资源码不能为空") @Size(max = 128, message = "资源码过长") String resourceCode,
            @NotBlank(message = "范围类型不能为空") @Size(max = 32, message = "范围类型过长") String scope,
            boolean includeChild,
            @Size(max = 128, message = "指定部门最多 128 个") List<String> deptIds) {}
}
