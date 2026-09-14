package ${basePackage}.module.${moduleCode}.vo;

<#list imports as item>import ${item};
</#list>
/** ${table.comment}响应视图。 */
public record ${table.entityName}View(
<#list viewApiColumns as column>
        ${column.apiType} ${column.fieldName}<#if column_has_next>,</#if>
</#list>
) {
}
