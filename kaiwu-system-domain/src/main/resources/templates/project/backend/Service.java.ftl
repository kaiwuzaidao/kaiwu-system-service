package ${basePackage}.module.${moduleCode}.service;

import ${basePackage}.module.${moduleCode}.entity.${table.entityName};
import com.baomidou.mybatisplus.core.metadata.IPage;

/** ${table.comment}业务用例；实现负责数据范围与状态校验。 */
public interface ${table.entityName}Service {

    /**
     * 在授权范围内分页查询${table.comment}。
     *
     * @param query 筛选条件
     * @param current 从 1 开始的页码
     * @param size 单页行数
     * @return 分页实体结果
     */
    IPage<${table.entityName}> page(${table.entityName} query, long current, long size);

    /**
     * 查询当前调用方可见的${table.comment}。
     *
     * @param id 资源主键
     * @return 实体；不存在或无权访问时由实现决定失败语义
     */
    ${table.entityName} get(${pkType} id);

    /**
     * 创建${table.comment}。
     *
     * @param entity 仅包含允许写入字段的实体
     */
    void create(${table.entityName} entity);

    /**
     * 更新当前调用方有权操作的${table.comment}。
     *
     * @param id 资源主键
     * @param entity 仅包含允许更新字段的实体
     */
    void update(${pkType} id, ${table.entityName} entity);

    /**
     * 删除当前调用方有权操作的${table.comment}。
     *
     * @param id 资源主键
     */
    void delete(${pkType} id);
}
