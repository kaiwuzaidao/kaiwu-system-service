package com.kaiwu.module.projectgeneration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.module.codegen.AiMetadataEnhancer;
import com.kaiwu.module.codegen.DdlParser;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationCreateRequest;
import com.kaiwu.port.ProjectGenerationAiPort;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

class ProjectBlueprintServiceTest {

    @Test
    void userSuppliedDdlContinuesWithDeterministicMetadataWhenAiEnhancementFails() {
        ProjectGenerationAiPort ai = mock(ProjectGenerationAiPort.class);
        AiMetadataEnhancer enhancer = mock(AiMetadataEnhancer.class);
        when(ai.effectiveConfig())
                .thenReturn(Optional.of(new ProjectGenerationAiPort.RuntimeConfig(
                        "test", "https://model.example/v1", null, "test-model", new BigDecimal("0.2"), 10)));
        when(enhancer.enhance(anyList(), anyString()))
                .thenReturn(new AiMetadataEnhancer.EnhanceResult("DETERMINISTIC_FALLBACK", "test-model", ""));

        ProjectBlueprintService service =
                new ProjectBlueprintService(ai, new DdlParser(), enhancer, new ObjectMapper());
        ProjectView project = new ProjectView(
                "1",
                "billing",
                "记账后台",
                null,
                "ACTIVE",
                false,
                "1",
                "com.example.billing",
                null,
                null,
                "main",
                null,
                null,
                null,
                LocalDateTime.now(),
                LocalDateTime.now());
        ProjectGenerationCreateRequest request = new ProjectGenerationCreateRequest(
                "1",
                "AI_PROJECT",
                "记账管理",
                """
                        CREATE TABLE biz_ledger (
                          id BIGINT NOT NULL COMMENT '主键',
                          amount DECIMAL(18,2) NOT NULL COMMENT '金额',
                          PRIMARY KEY (id)
                        ) COMMENT='账目';
                        """);

        ProjectBlueprintService.ProjectBlueprint blueprint = service.create(project, request);

        assertThat(blueprint.designSummary()).isEqualTo("已根据业务描述生成第一版数据模型与后台模块");
        assertThat(blueprint.tables()).hasSize(1);
        verify(enhancer).enhance(anyList(), anyString());
        verify(enhancer, never()).enhanceRequired(anyList(), anyString());
    }

    @Test
    void aiGeneratedSchemaRequiresAiMenuMetadata() {
        ProjectGenerationAiPort ai = mock(ProjectGenerationAiPort.class);
        AiMetadataEnhancer enhancer = mock(AiMetadataEnhancer.class);
        when(ai.effectiveConfig())
                .thenReturn(Optional.of(new ProjectGenerationAiPort.RuntimeConfig(
                        "test", "https://model.example/v1", null, "test-model", new BigDecimal("0.2"), 10)));
        when(ai.chat(
                        org.mockito.ArgumentMatchers.any(),
                        anyString(),
                        anyString(),
                        org.mockito.ArgumentMatchers.anyInt()))
                .thenReturn(
                        """
                        CREATE TABLE reimburse_prompt_config (
                          id BIGINT NOT NULL COMMENT '主键',
                          PRIMARY KEY (id)
                        ) COMMENT '提示词配置';
                        """);
        when(enhancer.enhanceRequired(anyList(), anyString()))
                .thenReturn(new AiMetadataEnhancer.EnhanceResult("AI_METADATA", "test-model", "提示词配置模块"));

        ProjectBlueprintService service =
                new ProjectBlueprintService(ai, new DdlParser(), enhancer, new ObjectMapper());
        ProjectView project = new ProjectView(
                "1",
                "reimburse",
                "记账后台",
                null,
                "ACTIVE",
                false,
                "1",
                "com.example.reimburse",
                null,
                null,
                "main",
                null,
                null,
                null,
                LocalDateTime.now(),
                LocalDateTime.now());
        ProjectGenerationCreateRequest request =
                new ProjectGenerationCreateRequest("1", "AI_PROJECT", "管理小程序提示词配置", null);

        service.create(project, request);

        verify(enhancer).enhanceRequired(anyList(), anyString());
        verify(enhancer, never()).enhance(anyList(), anyString());
    }
}
