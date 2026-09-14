package ${basePackage}.module.${moduleCode}.service;

import ${basePackage}.common.ApiException;
import ${basePackage}.common.PageBounds;
import ${basePackage}.module.${moduleCode}.entity.${table.entityName};
import ${basePackage}.module.${moduleCode}.mapper.${table.entityName}Mapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
<#if ownerScoped>import com.kaiwu.starter.StarterContext;
</#if>import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class ${table.entityName}Service {

    private final ${table.entityName}Mapper mapper;

    public ${table.entityName}Service(${table.entityName}Mapper mapper) {
        this.mapper = mapper;
    }

    public IPage<${table.entityName}> page(
            ${table.entityName} query,
            long current,
            long size
    ) {
        // 越界直接拒绝，不截断：无上限的 size 等于允许调用方要求全表。
        PageBounds.require(current, size);
        return mapper.selectPage(new Page<>(current, size),
                Wrappers.<${table.entityName}>lambdaQuery()
<#list table.searchColumns() as column>
<#if column.javaType == "String">
                        .like(
                                StringUtils.hasText(query.get${column.fieldName?cap_first}()),
                                ${table.entityName}::get${column.fieldName?cap_first},
                                query.get${column.fieldName?cap_first}())
<#else>
                        .eq(
                                query.get${column.fieldName?cap_first}() != null,
                                ${table.entityName}::get${column.fieldName?cap_first},
                                query.get${column.fieldName?cap_first}())
</#if>
</#list>
<#if ownerScoped>                        .eq(${table.entityName}::get${ownerField?cap_first}, currentOwnerId())
</#if>        );
    }

    public ${table.entityName} get(${pkType} id) {
<#if ownerScoped>        ${table.entityName} entity = mapper.selectOne(
                Wrappers.<${table.entityName}>lambdaQuery()
                        .eq(${table.entityName}::get${pkField?cap_first}, id)
                        .eq(${table.entityName}::get${ownerField?cap_first}, currentOwnerId()));
        return requireVisible(entity);
<#else>        return mapper.selectById(id);
</#if>    }

    public void create(${table.entityName} entity) {
<#if ownerScoped>        entity.set${ownerField?cap_first}(currentOwnerId());
</#if>        mapper.insert(entity);
    }

    public void update(${pkType} id, ${table.entityName} entity) {
<#if saveApiColumns?size == 0>        throw new ApiException(
                HttpStatus.BAD_REQUEST, "当前资源没有可更新字段", "error.validation.failed");
<#else>        LambdaUpdateWrapper<${table.entityName}> updates =
                new LambdaUpdateWrapper<${table.entityName}>()
<#list saveApiColumns as column>                        .set(${table.entityName}::get${column.fieldName?cap_first}, entity.get${column.fieldName?cap_first}())
</#list>                        .eq(${table.entityName}::get${pkField?cap_first}, id)
<#if ownerScoped>                        .eq(${table.entityName}::get${ownerField?cap_first}, currentOwnerId())
</#if>                ;
        requireAffected(mapper.update(null, updates));
</#if>    }

    public void delete(${pkType} id) {
<#if ownerScoped>        requireAffected(mapper.delete(
                Wrappers.<${table.entityName}>lambdaQuery()
                        .eq(${table.entityName}::get${pkField?cap_first}, id)
                        .eq(${table.entityName}::get${ownerField?cap_first}, currentOwnerId())));
<#else>        requireAffected(mapper.deleteById(id));
</#if>    }

<#if ownerScoped>    private ${ownerJavaType} currentOwnerId() {
        if (!StringUtils.hasText(StarterContext.userId())) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN, "缺少有效的当前用户", "error.access.denied");
        }
        try {
            return ${ownerValueExpression};
        } catch (NumberFormatException exception) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN, "当前用户标识格式无效", "error.access.denied");
        }
    }

    private ${table.entityName} requireVisible(${table.entityName} entity) {
        if (entity == null) {
            throw resourceNotFound();
        }
        return entity;
    }

</#if>    private void requireAffected(int affected) {
        if (affected != 1) {
            throw resourceNotFound();
        }
    }

    private ApiException resourceNotFound() {
        return new ApiException(
                HttpStatus.NOT_FOUND, "资源不存在或无权访问", "error.resource.notFound");
    }
}
