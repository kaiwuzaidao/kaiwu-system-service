package demo.crm;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.kaiwu.starter.KaiwuContext;
import com.kaiwu.starter.agent.AgentExecutionCodec;
import com.kaiwu.starter.agent.AgentReadCapabilityHandler;
import com.kaiwu.starter.agent.protocol.CapabilityManifest;
import com.kaiwu.starter.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.agent.protocol.DataScope;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 只读 Agent 能力 {@code demo-crm.customer.list}：声明 ROLE_SCOPED，Handler 里**没有任何范围代码**，
 * 直接复用与 HTTP 列表相同的 Mapper 查询——Agent Context 带的 ds 由数据范围模块按同一规则过滤。
 */
@Configuration
public class AgentConfig {
    static final CapabilityManifest MANIFEST = new CapabilityManifest(
            "demo-crm",
            "demo-crm.customer.list",
            "1",
            "查询我有权查看的客户",
            "democrm:customer:list",
            DataScope.ROLE_SCOPED,
            Map.of(),
            Set.of("id", "name"),
            Map.of(),
            true,
            true,
            ConfirmationMode.NONE,
            3000);

    @Bean
    AgentReadCapabilityHandler customerList(CustomerMapper mapper) {
        return new AgentReadCapabilityHandler() {
            @Override
            public CapabilityManifest manifest() {
                return MANIFEST;
            }

            @Override
            public List<Map<String, Object>> query(Map<String, Object> parameters, KaiwuContext actor) {
                return mapper.selectList(new LambdaQueryWrapper<Customer>().orderByAsc(Customer::getId)).stream()
                        .map(c -> {
                            Map<String, Object> row = new LinkedHashMap<>();
                            row.put("id", String.valueOf(c.id));
                            row.put("name", c.name);
                            return row;
                        })
                        .toList();
            }
        };
    }

    /** 联调脚本取清单摘要用；路径在 /demo/** 下，已从 Starter 的拦截范围排除，仅本机夹具使用。 */
    @RestController
    static class MetaController {
        @GetMapping("/demo/agent-meta")
        Map<String, String> meta() {
            return Map.of(
                    "code", MANIFEST.code(),
                    "version", MANIFEST.version(),
                    "manifestHash", AgentExecutionCodec.manifestHash(MANIFEST));
        }
    }
}
