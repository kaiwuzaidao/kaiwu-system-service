package com.kaiwu.module.codegen;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.ai.AiProviderService;
import com.kaiwu.module.ai.OpenAiCompatibleClient;
import com.kaiwu.module.codegen.model.TableMeta;
import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

class AiMetadataEnhancerTest {

    @Test
    void appliesOnlyKnownFieldMetadataAndNeverAcceptsExecutableOutput() throws Exception {
        AiProviderService providerService = mock(AiProviderService.class);
        OpenAiCompatibleClient client = mock(OpenAiCompatibleClient.class);
        when(providerService.effective())
                .thenReturn(Optional.of(new AiProviderService.RuntimeConfig(
                        "test", "http://model.test/v1", null, "test-model", new BigDecimal("0.2"), 10)));
        when(client.chat(any(), anyString(), anyString(), anyInt()))
                .thenReturn(new OpenAiCompatibleClient.ChatResult(
                        """
                        ```json
                        {
                          "designSummary": "订单列表字段元数据",
                          "tables": {
                            "biz_order": {
                              "label": "订单管理",
                              "fields": {
                                "order_no": {"label": "业务订单号", "searchable": true},
                                "created_at": {"label": "创建时间", "searchable": true},
                                "unknown": {"label": "DROP TABLE", "searchable": true}
                              },
                              "sql": "DROP TABLE sys_user"
                            }
                          }
                        }
                        ```
                        """,
                        10L,
                        20L));
        List<TableMeta> tables = new DdlParser()
                .parseAll(
                        """
                CREATE TABLE biz_order (
                  id BIGINT NOT NULL COMMENT '主键',
                  order_no VARCHAR(64) NOT NULL COMMENT '订单号',
                  created_at DATETIME NOT NULL COMMENT '创建时间',
                  PRIMARY KEY (id)
                ) COMMENT='订单'
                """);

        AiMetadataEnhancer.EnhanceResult result =
                new AiMetadataEnhancer(providerService, client, new ObjectMapper()).enhance(tables, "订单管理");

        assertThat(result.generationMode()).isEqualTo("AI_METADATA");
        assertThat(result.model()).isEqualTo("test-model");
        assertThat(tables.getFirst().getComment()).isEqualTo("订单管理");
        assertThat(tables.getFirst().getColumns().stream()
                        .filter(column -> "order_no".equals(column.getColumnName()))
                        .findFirst()
                        .orElseThrow()
                        .getLabel())
                .isEqualTo("业务订单号");
        assertThat(tables.getFirst().getColumns().stream()
                        .filter(column -> "created_at".equals(column.getColumnName()))
                        .findFirst()
                        .orElseThrow()
                        .isSearchable())
                .isFalse();
        assertThat(tables.getFirst().getColumns()).noneMatch(column -> "unknown".equals(column.getColumnName()));
    }

    @Test
    void acceptsEnglishMenuLabelButRejectsNonAsciiOne() throws Exception {
        // 英文菜单名会被直接写进生成项目的英文语言包，因此非 ASCII 内容一律拒收：
        // 模型可能把中文或注入文本放进该字段。
        List<TableMeta> accepted = enhanceWithTableNode("\"label\": \"订单管理\", \"labelEn\": \"Order Management\"");
        // 先确认中文 label 生效，以区分「整条 tableUpdate 未生效」与「英文校验拒收」
        assertThat(accepted.getFirst().getComment()).isEqualTo("订单管理");
        assertThat(accepted.getFirst().getCommentEn()).isEqualTo("Order Management");

        List<TableMeta> rejected = enhanceWithTableNode("\"label\": \"订单管理\", \"labelEn\": \"订单管理\"");
        assertThat(rejected.getFirst().getCommentEn()).isNull();

        List<TableMeta> missing = enhanceWithTableNode("\"label\": \"订单管理\"");
        assertThat(missing.getFirst().getCommentEn()).isNull();
    }

    private static List<TableMeta> enhanceWithTableNode(String tableProperties) throws Exception {
        AiProviderService providerService = mock(AiProviderService.class);
        OpenAiCompatibleClient client = mock(OpenAiCompatibleClient.class);
        when(providerService.effective())
                .thenReturn(Optional.of(new AiProviderService.RuntimeConfig(
                        "test", "http://model.test/v1", null, "test-model", new BigDecimal("0.2"), 10)));
        when(client.chat(any(), anyString(), anyString(), anyInt()))
                .thenReturn(new OpenAiCompatibleClient.ChatResult(
                        "{\"designSummary\":\"s\",\"tables\":{\"biz_order\":{"
                                + tableProperties
                                + ",\"fields\":{\"order_no\":"
                                + "{\"label\":\"订单号\",\"searchable\":true}}}}}",
                        10L,
                        20L));
        List<TableMeta> tables = new DdlParser()
                .parseAll(
                        """
                CREATE TABLE biz_order (
                  id BIGINT NOT NULL COMMENT '主键',
                  order_no VARCHAR(64) NOT NULL COMMENT '订单号',
                  PRIMARY KEY (id)
                ) COMMENT='订单'
                """);
        new AiMetadataEnhancer(providerService, client, new ObjectMapper()).enhance(tables, "订单管理");
        return tables;
    }

    @Test
    void fallsBackWhenProviderIsNotEnabled() {
        AiProviderService providerService = mock(AiProviderService.class);
        when(providerService.effective()).thenReturn(Optional.empty());

        AiMetadataEnhancer.EnhanceResult result = new AiMetadataEnhancer(
                        providerService, mock(OpenAiCompatibleClient.class), new ObjectMapper())
                .enhance(List.of(), null);

        assertThat(result.generationMode()).isEqualTo("DETERMINISTIC_FALLBACK");
        assertThat(result.model()).isNull();
    }

    @Test
    void requiredModeRejectsAJsonObjectWithoutKnownFieldUpdates() {
        AiProviderService providerService = mock(AiProviderService.class);
        OpenAiCompatibleClient client = mock(OpenAiCompatibleClient.class);
        when(providerService.effective())
                .thenReturn(Optional.of(new AiProviderService.RuntimeConfig(
                        "test", "https://model.example/v1", null, "test-model", new BigDecimal("0.2"), 10)));
        when(client.chat(any(), anyString(), anyString(), anyInt()))
                .thenReturn(new OpenAiCompatibleClient.ChatResult("{}", null, null));
        List<TableMeta> tables = new DdlParser()
                .parseAll(
                        """
                CREATE TABLE biz_order (
                  id BIGINT NOT NULL COMMENT '主键',
                  order_no VARCHAR(64) NOT NULL COMMENT '订单号',
                  PRIMARY KEY (id)
                ) COMMENT='订单'
                """);

        AiMetadataEnhancer enhancer = new AiMetadataEnhancer(providerService, client, new ObjectMapper());

        assertThatThrownBy(() -> enhancer.enhanceRequired(tables, "订单管理"))
                .isInstanceOf(ApiException.class)
                .satisfies(error ->
                        assertThat(((ApiException) error).getStatus().value()).isEqualTo(502));
    }

    @Test
    void requiredModeRejectsTechnicalTableNameAsMenuLabel() {
        AiProviderService providerService = mock(AiProviderService.class);
        OpenAiCompatibleClient client = mock(OpenAiCompatibleClient.class);
        when(providerService.effective())
                .thenReturn(Optional.of(new AiProviderService.RuntimeConfig(
                        "test", "https://model.example/v1", null, "test-model", new BigDecimal("0.2"), 10)));
        when(client.chat(any(), anyString(), anyString(), anyInt()))
                .thenReturn(new OpenAiCompatibleClient.ChatResult(
                        """
                        {
                          "designSummary": "提示词配置",
                          "tables": {
                            "reimburse_prompt_config": {
                              "label": "reimburse_prompt_config",
                              "fields": {
                                "id": {"label": "主键", "searchable": false}
                              }
                            }
                          }
                        }
                        """,
                        null,
                        null));
        List<TableMeta> tables = new DdlParser()
                .parseAll(
                        """
                CREATE TABLE reimburse_prompt_config (
                  id BIGINT NOT NULL COMMENT '主键',
                  PRIMARY KEY (id)
                );
                """);

        AiMetadataEnhancer enhancer = new AiMetadataEnhancer(providerService, client, new ObjectMapper());

        assertThatThrownBy(() -> enhancer.enhanceRequired(tables, "提示词配置管理"))
                .isInstanceOf(ApiException.class)
                .satisfies(error ->
                        assertThat(((ApiException) error).getStatus().value()).isEqualTo(502));
    }
}
