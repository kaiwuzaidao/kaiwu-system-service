package ${basePackage}.module.${moduleCode}.mapper;

import ${basePackage}.module.${moduleCode}.entity.${table.entityName};
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface ${table.entityName}Mapper extends BaseMapper<${table.entityName}> {
}
