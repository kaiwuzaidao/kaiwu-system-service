package ${basePackage}.module.${moduleCode}.dto;

<#list imports as item>import ${item};
</#list>
<#if hasNotBlank>import jakarta.validation.constraints.NotBlank;
</#if><#if hasNotNull>import jakarta.validation.constraints.NotNull;
</#if>
/** ${table.comment}保存请求。 */
public record ${table.entityName}SaveRequest(
<#list saveApiColumns as column>
<#if !column.nullable><#if column.stringValue>        @NotBlank(message = "${column.fieldName}不能为空")
<#else>        @NotNull(message = "${column.fieldName}不能为空")
</#if></#if>        ${column.apiType} ${column.fieldName}<#if column_has_next>,</#if>
</#list>
) {
}
