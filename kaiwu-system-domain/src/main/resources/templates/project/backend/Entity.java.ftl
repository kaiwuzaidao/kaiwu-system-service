package ${basePackage}.module.${moduleCode}.entity;

import com.baomidou.mybatisplus.annotation.TableId;
<#if hasLogicDelete>import com.baomidou.mybatisplus.annotation.TableLogic;
</#if>import com.baomidou.mybatisplus.annotation.TableName;
<#list imports as item>import ${item};
</#list>
/** ${table.comment}实体。 */
@TableName("${table.tableName}")
public class ${table.entityName} {

<#list table.columns as column>
    /** ${column.label} */
<#if column.primaryKey>    @TableId
</#if><#if column.logicDelete>    @TableLogic
</#if>    private ${column.javaType} ${column.fieldName};

</#list>
<#list table.columns as column>
    public ${column.javaType} get${column.fieldName?cap_first}() {
        return ${column.fieldName};
    }

    public void set${column.fieldName?cap_first}(${column.javaType} ${column.fieldName}) {
        this.${column.fieldName} = ${column.fieldName};
    }

</#list>
}
