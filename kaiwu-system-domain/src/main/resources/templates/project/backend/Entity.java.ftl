package ${basePackage}.module.${moduleCode}.entity;

<#if dataScoped>import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.FieldStrategy;
import com.baomidou.mybatisplus.annotation.TableField;
</#if>import com.baomidou.mybatisplus.annotation.TableId;
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
</#if><#if dataScoped && (column.columnName?lower_case == "owner_user_id" || column.columnName?lower_case == "owner_dept_id")>    @TableField(fill = FieldFill.INSERT, updateStrategy = FieldStrategy.NEVER)
</#if>    private ${column.javaType} ${column.fieldName};

</#list>
<#list table.columns as column>
    /**
     * 获取${column.label}。
     *
     * @return ${column.label}
     */
    public ${column.javaType} get${column.fieldName?cap_first}() {
        return ${column.fieldName};
    }

    /**
     * 设置${column.label}。
     *
     * @param ${column.fieldName} ${column.label}
     */
    public void set${column.fieldName?cap_first}(${column.javaType} ${column.fieldName}) {
        this.${column.fieldName} = ${column.fieldName};
    }

</#list>
}
