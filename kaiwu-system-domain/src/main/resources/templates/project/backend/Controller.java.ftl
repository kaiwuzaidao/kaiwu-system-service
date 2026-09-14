package ${basePackage}.module.${moduleCode}.controller;

import ${basePackage}.common.PageResult;
import ${basePackage}.common.Result;
import ${basePackage}.module.${moduleCode}.dto.${table.entityName}SaveRequest;
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

@RestController
@RequestMapping("/api/${moduleCode}/${resourceCode}")
public class ${table.entityName}Controller {

    private final ${table.entityName}Service service;

    public ${table.entityName}Controller(${table.entityName}Service service) {
        this.service = service;
    }

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

    @GetMapping("/{id}")
    @RequirePermission("${permissionPrefix}:list")
    public Result<${table.entityName}View> get(@PathVariable ${pkType} id) {
        return Result.ok(toView(service.get(id)));
    }

    @PostMapping
    @RequirePermission("${permissionPrefix}:save")
    public Result<Void> create(@Valid @RequestBody ${table.entityName}SaveRequest request) {
        service.create(toEntity(request));
        return Result.ok(null);
    }

    @PutMapping("/{id}")
    @RequirePermission("${permissionPrefix}:save")
    public Result<Void> update(
            @PathVariable ${pkType} id,
            @Valid @RequestBody ${table.entityName}SaveRequest request
    ) {
        service.update(id, toEntity(request));
        return Result.ok(null);
    }

    @DeleteMapping("/{id}")
    @RequirePermission("${permissionPrefix}:delete")
    public Result<Void> delete(@PathVariable ${pkType} id) {
        service.delete(id);
        return Result.ok(null);
    }

    private ${table.entityName} toEntity(${table.entityName}SaveRequest request) {
        ${table.entityName} entity = new ${table.entityName}();
<#list saveApiColumns as column>
        entity.set${column.fieldName?cap_first}(${column.toEntityExpression});
</#list>
        return entity;
    }

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
