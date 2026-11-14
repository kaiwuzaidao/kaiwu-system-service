package ${basePackage}.module.${moduleCode}.controller;

import ${basePackage}.common.PageResult;
import ${basePackage}.common.Result;
import ${basePackage}.module.${moduleCode}.dto.request.${table.entityName}SaveRequest;
import ${basePackage}.module.${moduleCode}.vo.${table.entityName}View;
import ${basePackage}.module.${moduleCode}.entity.${table.entityName};
import ${basePackage}.module.${moduleCode}.service.${table.entityName}Service;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.kaiwu.starter.RequirePermission;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 提供${table.comment}的 HTTP 协议入口；权限、参数校验和响应映射在此收口，领域规则委托给 Service。
 */
@RestController
@RequestMapping("/api/${moduleCode}/${resourceCode}")
public class ${table.entityName}Controller {

    private final ${table.entityName}Service service;

    /**
     * 注入${table.comment}业务用例。
     *
     * @param service 负责领域处理和数据范围校验的服务
     */
    public ${table.entityName}Controller(${table.entityName}Service service) {
        this.service = service;
    }

    /**
     * 在当前项目的授权范围内分页查询${table.comment}。
     *
     * @param query 用于筛选的领域查询对象
     * @param current 从 1 开始的页码
     * @param size 单页行数，服务层会拒绝越界值
     * @return 统一分页响应
     */
    @GetMapping
    @RequirePermission("${permissionPrefix}:list")
    public Result<PageResult<${table.entityName}View>> page(
            ${table.entityName} query,
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "10") long size
    ) {
        IPage<${table.entityName}> page = service.page(query, current, size);
        return Result.ok(new PageResult<>(
                page.getCurrent(), page.getSize(), page.getTotal(),
                page.getRecords().stream().map(this::toView).toList()));
    }

    /**
     * 查询当前调用方可见的一条${table.comment}。
     *
     * @param id 资源主键
     * @return 统一详情响应
     */
    @GetMapping("/{id}")
    @RequirePermission("${permissionPrefix}:list")
    public Result<${table.entityName}View> get(@PathVariable ${pkType} id) {
        return Result.ok(toView(service.get(id)));
    }

    /**
     * 创建${table.comment}，权限和字段校验在写入前完成。
     *
     * @param request 已通过 Bean Validation 的保存请求
     * @return 空成功响应
     */
    @PostMapping
    @RequirePermission("${permissionPrefix}:save")
    public Result<Void> create(@Valid @RequestBody ${table.entityName}SaveRequest request) {
        service.create(toEntity(request));
        return Result.ok(null);
    }

    /**
     * 更新指定${table.comment}的可编辑字段。
     *
     * @param id 资源主键
     * @param request 已通过 Bean Validation 的保存请求
     * @return 空成功响应
     */
    @PutMapping("/{id}")
    @RequirePermission("${permissionPrefix}:save")
    public Result<Void> update(
            @PathVariable ${pkType} id,
            @Valid @RequestBody ${table.entityName}SaveRequest request
    ) {
        service.update(id, toEntity(request));
        return Result.ok(null);
    }

    /**
     * 删除当前调用方有权操作的${table.comment}。
     *
     * @param id 资源主键
     * @return 空成功响应
     */
    @DeleteMapping("/{id}")
    @RequirePermission("${permissionPrefix}:delete")
    public Result<Void> delete(@PathVariable ${pkType} id) {
        service.delete(id);
        return Result.ok(null);
    }

    /**
     * 将外部保存请求转换为不含主键、审计字段和归属字段的领域实体。
     *
     * @param request 已校验的保存请求
     * @return 仅包含可写字段的实体
     */
    private ${table.entityName} toEntity(${table.entityName}SaveRequest request) {
        ${table.entityName} entity = new ${table.entityName}();
<#list saveApiColumns as column>
        entity.set${column.fieldName?cap_first}(${column.toEntityExpression});
</#list>
        return entity;
    }

    /**
     * 将持久化实体转换为对外稳定的响应视图。
     *
     * @param entity 领域实体；允许为空
     * @return 对外视图；实体为空时返回空
     */
    private ${table.entityName}View toView(${table.entityName} entity) {
        if (entity == null) {
            return null;
        }
        return new ${table.entityName}View(
<#list viewApiColumns as column>
                ${column.toViewExpression}<#if column_has_next>,</#if>
</#list>
        );
    }
}
