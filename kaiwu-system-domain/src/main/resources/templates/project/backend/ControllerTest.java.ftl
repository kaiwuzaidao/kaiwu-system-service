package ${basePackage}.module.${moduleCode}.controller;

import ${basePackage}.module.${moduleCode}.entity.${table.entityName};
import ${basePackage}.module.${moduleCode}.service.${table.entityName}Service;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * ${table.comment}接口的测试基线。
 *
 * <p>用 standalone MockMvc 只装配这一个 Controller，Service 打桩：不起 Spring 容器、
 * 不连数据库，CI 里无条件可跑。这里锁住的是**对外 JSON 契约**——路由、响应外壳形状，
 * 以及长整型 ID 必须以字符串出现（JavaScript 的 Number 只有 53 位精度，
 * 19 位 ID 直接序列化成数字会在前端悄悄变值，且没有任何报错）。</p>
 *
 * <p>注意：`@RequirePermission` 由 Starter 的拦截器执行，standalone 模式下不参与，
 * 因此本类不校验权限；权限码的一致性由 {@code scripts/check-permission-seed.sh} 保证。</p>
 *
 * <p>新增接口时在本类补用例。删掉这个文件会让
 * {@code scripts/check-test-baseline.sh --strict} 能发现模板测试骨架被误删。</p>
 */
class ${table.entityName}ControllerTest {

    private final ${table.entityName}Service service = mock(${table.entityName}Service.class);

    private final MockMvc mvc = MockMvcBuilders
            .standaloneSetup(new ${table.entityName}Controller(service))
            .build();

    @Test
    void pageReturnsUnifiedEnvelope() throws Exception {
        ${table.entityName} record = new ${table.entityName}();
<#if pkSample != "null">
        record.set${pkField?cap_first}(${pkSample});
</#if>
        Page<${table.entityName}> page = new Page<>(1, 10, 1);
        page.setRecords(List.of(record));
        when(service.page(any(), anyLong(), anyLong())).thenReturn(page);

        mvc.perform(get("/api/${moduleCode}/${resourceCode}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.total").value(1))
<#if pkIsLongIdentifier>
                // 长整型 ID 必须是字符串：改成数字前端不会报错，只会静默丢精度。
                .andExpect(jsonPath("$.data.records[0].${pkField}").isString())
</#if>
                .andExpect(jsonPath("$.data.records[0]").exists());
    }

    @Test
    void deleteDelegatesToServiceAndReturnsOk() throws Exception {
        mvc.perform(delete("/api/${moduleCode}/${resourceCode}/{id}", ${pkPathSample}))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));

        verify(service).delete(${pkSample});
    }

    @Test
    void updateTakesIdentityFromPathAndReturnsOk() throws Exception {
        mvc.perform(put("/api/${moduleCode}/${resourceCode}/{id}", ${pkPathSample})
                        .contentType("application/json")
                        .content("${validRequestJson}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));

        verify(service).update(org.mockito.ArgumentMatchers.eq(${pkSample}), any());
    }
}
