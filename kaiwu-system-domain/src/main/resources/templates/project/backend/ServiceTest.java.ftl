package ${basePackage}.module.${moduleCode}.service;

import ${basePackage}.module.${moduleCode}.service.impl.${table.entityName}ServiceImpl;

import ${basePackage}.common.ApiException;
import ${basePackage}.module.${moduleCode}.entity.${table.entityName};
import ${basePackage}.module.${moduleCode}.mapper.${table.entityName}Mapper;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.conditions.Wrapper;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
<#if ownerScoped>import com.kaiwu.starter.StarterContext;
</#if>import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
<#if ownerScoped>import org.mockito.ArgumentCaptor;
import org.mockito.MockedStatic;
</#if>
import static org.assertj.core.api.Assertions.assertThat;
<#if ownerScoped || dataScoped>import static org.assertj.core.api.Assertions.assertThatThrownBy;
</#if>import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.mock;
<#if ownerScoped>import static org.mockito.Mockito.mockStatic;
</#if>import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** ${table.comment}服务的行为和资源授权测试基线。 */
class ${table.entityName}ServiceTest {

    /**
     * 初始化 MyBatis-Plus 实体元数据，使条件构造器可在无数据库时工作。
     */
    @BeforeAll
    static void initEntityMetadata() {
        TableInfoHelper.initTableInfo(
                new MapperBuilderAssistant(new MybatisConfiguration(), ""),
                ${table.entityName}.class);
    }

    private final ${table.entityName}Mapper mapper = mock(${table.entityName}Mapper.class);
    private final ${table.entityName}Service service = new ${table.entityName}ServiceImpl(mapper);

    /**
     * 验证新增与修改分别走独立命令，不复用同一入参。
     */
    @Test
    void createsAndUpdatesThroughSeparateCommands() {
<#if ownerScoped>        try (MockedStatic<StarterContext> context = mockStatic(StarterContext.class)) {
            context.when(StarterContext::userId).thenReturn("${ownerUserIdSample}");
</#if>            ${table.entityName} created = new ${table.entityName}();
            service.create(created);
<#if ownerScoped>            assertThat(created.get${ownerField?cap_first}()).isEqualTo(${ownerSample});
</#if>            verify(mapper).insert(created);

            clearInvocations(mapper);
            when(mapper.update(isNull(), any(Wrapper.class))).thenReturn(1);
            service.update(${pkSample}, new ${table.entityName}());
            verify(mapper).update(isNull(), any(Wrapper.class));
<#if ownerScoped>        }
</#if>    }

<#if ownerScoped>
    /**
     * 验证当前用户看不到其数据范围之外的记录。
     */
    @Test
    void hidesRecordsOutsideCurrentOwnerScope() {
        try (MockedStatic<StarterContext> context = mockStatic(StarterContext.class)) {
            context.when(StarterContext::userId).thenReturn("${ownerUserIdSample}");
            when(mapper.selectOne(any(Wrapper.class))).thenReturn(null);

            assertThatThrownBy(() -> service.get(${pkSample}))
                    .isInstanceOf(ApiException.class)
                    .hasMessage("资源不存在或无权访问");

            @SuppressWarnings("unchecked")
            ArgumentCaptor<Wrapper<${table.entityName}>> query =
                    ArgumentCaptor.forClass(Wrapper.class);
            verify(mapper).selectOne(query.capture());
            assertThat(query.getValue().getSqlSegment()).contains("${ownerColumn.columnName}");
        }
    }

</#if>
<#if dataScoped>
    /**
     * 验证数据范围拦截器过滤掉的记录对调用方表现为不存在，而不是返回空数据或 403。
     */
    @Test
    void hidesRecordsFilteredByTheDataScope() {
        when(mapper.selectById(${pkSample})).thenReturn(null);

        assertThatThrownBy(() -> service.get(${pkSample}))
                .isInstanceOf(ApiException.class)
                .hasMessage("资源不存在或无权访问");
    }

</#if>
    /**
     * 验证删除按声明的资源范围限定条件执行。
     */
    @Test
    void deleteUsesTheDeclaredResourceScope() {
<#if ownerScoped>        try (MockedStatic<StarterContext> context = mockStatic(StarterContext.class)) {
            context.when(StarterContext::userId).thenReturn("${ownerUserIdSample}");
            when(mapper.delete(any(Wrapper.class))).thenReturn(1);
            service.delete(${pkSample});
            verify(mapper).delete(any(Wrapper.class));
        }
<#else>        when(mapper.deleteById(${pkSample})).thenReturn(1);
        service.delete(${pkSample});
        verify(mapper).deleteById(${pkSample});
</#if>    }
}
