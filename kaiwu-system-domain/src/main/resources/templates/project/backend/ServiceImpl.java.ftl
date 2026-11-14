package ${basePackage}.module.${moduleCode}.service.impl;

import ${basePackage}.module.${moduleCode}.service.${table.entityName}Service;

import ${basePackage}.common.ApiException;
import ${basePackage}.common.PageBounds;
import ${basePackage}.module.${moduleCode}.entity.${table.entityName};
import ${basePackage}.module.${moduleCode}.mapper.${table.entityName}Mapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
<#if ownerScoped>import com.kaiwu.starter.StarterContext;
</#if><#if autoTimeColumns?size gt 0>import java.time.LocalDateTime;
</#if>import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

/**
 * 实现${table.comment}的持久化用例，并在查询与写入路径执行分页、可见范围和受影响行数校验。
 */
@Service
public class ${table.entityName}ServiceImpl implements ${table.entityName}Service {

    private final ${table.entityName}Mapper mapper;

    /**
     * 注入${table.comment}的持久化映射。
     *
     * @param mapper 业务表 Mapper
     */
    public ${table.entityName}ServiceImpl(${table.entityName}Mapper mapper) {
        this.mapper = mapper;
    }

    /**
     * 在当前数据范围内分页查询${table.comment}，并拒绝无界的外部分页参数。
     *
     * @param query 筛选条件
     * @param current 从 1 开始的页码
     * @param size 单页行数
     * @return 分页实体结果
     */
    @Override
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

    /**
     * 按主键读取${table.comment}；归属当前用户的资源会将不可见结果收敛为不存在。
     *
     * @param id 资源主键
     * @return 当前调用方可见的实体
     */
    @Override
    public ${table.entityName} get(${pkType} id) {
<#if ownerScoped>        ${table.entityName} entity = mapper.selectOne(
                Wrappers.<${table.entityName}>lambdaQuery()
                        .eq(${table.entityName}::get${pkField?cap_first}, id)
                        .eq(${table.entityName}::get${ownerField?cap_first}, currentOwnerId()));
        return requireVisible(entity);
<#elseif dataScoped>        // 数据范围由 kaiwu-data-scope 拦截器按角色自动追加，越权时查不到，统一按不存在处理。
        return requireVisible(mapper.selectById(id));
<#else>        return mapper.selectById(id);
</#if>    }

    /**
     * 创建${table.comment}；归属当前用户的资源由已验证上下文写入归属字段。
     *
     * @param entity 仅包含允许写入字段的实体
     */
    @Override
    public void create(${table.entityName} entity) {
<#if ownerScoped>        entity.set${ownerField?cap_first}(currentOwnerId());
</#if><#list autoTimeColumns as column>        entity.set${column.fieldName?cap_first}(LocalDateTime.now());
</#list>        mapper.insert(entity);
    }

    /**
     * 更新${table.comment}的可写字段，并用受影响行数避免把越权操作误报为成功。
     *
     * @param id 资源主键
     * @param entity 仅包含允许更新字段的实体
     */
    @Override
    public void update(${pkType} id, ${table.entityName} entity) {
<#if saveApiColumns?size == 0>        throw new ApiException(
                HttpStatus.BAD_REQUEST, "当前资源没有可更新字段", "error.validation.failed");
<#else>        LambdaUpdateWrapper<${table.entityName}> updates =
                new LambdaUpdateWrapper<${table.entityName}>()
<#list saveApiColumns as column>                        .set(${table.entityName}::get${column.fieldName?cap_first}, entity.get${column.fieldName?cap_first}())
</#list><#list autoTimeColumns as column><#if column.columnName?lower_case?contains("update")>                        .set(${table.entityName}::get${column.fieldName?cap_first}, LocalDateTime.now())
</#if></#list>                        .eq(${table.entityName}::get${pkField?cap_first}, id)
<#if ownerScoped>                        .eq(${table.entityName}::get${ownerField?cap_first}, currentOwnerId())
</#if>                ;
        requireAffected(mapper.update(null, updates));
</#if>    }

    /**
     * 删除${table.comment}，并把未命中或越权结果统一为资源不可见。
     *
     * @param id 资源主键
     */
    @Override
    public void delete(${pkType} id) {
<#if ownerScoped>        requireAffected(mapper.delete(
                Wrappers.<${table.entityName}>lambdaQuery()
                        .eq(${table.entityName}::get${pkField?cap_first}, id)
                        .eq(${table.entityName}::get${ownerField?cap_first}, currentOwnerId())));
<#else>        requireAffected(mapper.deleteById(id));
</#if>    }

<#if ownerScoped>    /**
     * 从 Gateway 已验证上下文取得归属范围，拒绝缺失或无法转换的用户标识。
     *
     * @return 与归属字段类型一致的当前用户标识
     */
    private ${ownerJavaType} currentOwnerId() {
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

</#if><#if ownerScoped || dataScoped>    /**
     * 将不存在与无权访问收敛为同一错误，避免泄露归属资源是否存在。
     *
     * @param entity 查询到的实体
     * @return 可见实体
     */
    private ${table.entityName} requireVisible(${table.entityName} entity) {
        if (entity == null) {
            throw resourceNotFound();
        }
        return entity;
    }

</#if>    /**
     * 确认写操作只影响一条可见资源。
     *
     * @param affected Mapper 返回的受影响行数
     */
    private void requireAffected(int affected) {
        if (affected != 1) {
            throw resourceNotFound();
        }
    }

    /**
     * 创建不泄露资源存在性的统一未找到异常。
     *
     * @return HTTP 404 业务异常
     */
    private ApiException resourceNotFound() {
        return new ApiException(
                HttpStatus.NOT_FOUND, "资源不存在或无权访问", "error.resource.notFound");
    }
}
