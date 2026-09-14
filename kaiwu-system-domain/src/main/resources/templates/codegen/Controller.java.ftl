package ${basePackage}.${moduleCode}.controller;

import ${basePackage}.${moduleCode}.entity.${table.entityName};
import ${basePackage}.${moduleCode}.service.${table.entityName}Service;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.kaiwu.common.PageResult;
import com.kaiwu.common.Result;
import com.kaiwu.starter.RequirePermission;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/${moduleCode}/${resourceCode}")
public class ${table.entityName}Controller {

    private final ${table.entityName}Service service;

    public ${table.entityName}Controller(${table.entityName}Service service) {
        this.service = service;
    }

    @GetMapping
    @RequirePermission("${permissionPrefix}:list")
    public Result<PageResult<${table.entityName}>> page(
            ${table.entityName} query,
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "10") long size
    ) {
        IPage<${table.entityName}> page = service.page(query, current, size);
        return Result.ok(new PageResult<>(
                page.getCurrent(), page.getSize(), page.getTotal(), page.getRecords()));
    }

    @GetMapping("/{id}")
    @RequirePermission("${permissionPrefix}:list")
    public Result<${table.entityName}> get(@PathVariable ${pkType} id) {
        return Result.ok(service.get(id));
    }

    @PostMapping
    @RequirePermission("${permissionPrefix}:save")
    public Result<Void> save(@RequestBody ${table.entityName} entity) {
        service.save(entity);
        return Result.ok(null);
    }

    @DeleteMapping("/{id}")
    @RequirePermission("${permissionPrefix}:delete")
    public Result<Void> delete(@PathVariable ${pkType} id) {
        service.delete(id);
        return Result.ok(null);
    }
}
