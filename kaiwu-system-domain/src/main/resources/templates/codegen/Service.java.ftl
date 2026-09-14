package ${basePackage}.${moduleCode}.service;

import ${basePackage}.${moduleCode}.entity.${table.entityName};
import ${basePackage}.${moduleCode}.mapper.${table.entityName}Mapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class ${table.entityName}Service {

    private final ${table.entityName}Mapper mapper;

    public ${table.entityName}Service(${table.entityName}Mapper mapper) {
        this.mapper = mapper;
    }

    public IPage<${table.entityName}> page(${table.entityName} query, long current, long size) {
        return mapper.selectPage(new Page<>(current, size),
                Wrappers.<${table.entityName}>lambdaQuery()
<#list table.searchColumns() as column>
                        .like(
                                StringUtils.hasText(query.get${column.fieldName?cap_first}()),
                                ${table.entityName}::get${column.fieldName?cap_first},
                                query.get${column.fieldName?cap_first}())
</#list>
        );
    }

    public ${table.entityName} get(${pkType} id) {
        return mapper.selectById(id);
    }

    public void save(${table.entityName} entity) {
        if (entity.get${pkField?cap_first}() == null) {
            mapper.insert(entity);
        } else {
            mapper.updateById(entity);
        }
    }

    public void delete(${pkType} id) {
        mapper.deleteById(id);
    }
}
