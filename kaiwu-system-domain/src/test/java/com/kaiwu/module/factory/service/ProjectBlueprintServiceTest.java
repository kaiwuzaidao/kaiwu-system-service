package com.kaiwu.module.factory.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.factory.renderer.DdlParser;
import com.kaiwu.module.factory.service.impl.ProjectBlueprintServiceImpl;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationCreateRequest;
import java.time.LocalDateTime;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

class ProjectBlueprintServiceTest {

    /** AI_PROJECT 已下线（ADR 0038）：直接以 400 拒绝。 */
    @Test
    void aiProjectModeIsRejectedWithoutTouchingAi() {
        ProjectBlueprintService service = new ProjectBlueprintServiceImpl(new DdlParser(), new ObjectMapper());
        ProjectView project = new ProjectView(
                "1",
                "crm",
                "跟进后台",
                null,
                "ACTIVE",
                false,
                "1",
                "com.example.crm",
                null,
                null,
                "main",
                null,
                null,
                null,
                LocalDateTime.now(),
                LocalDateTime.now());
        ProjectGenerationCreateRequest request =
                new ProjectGenerationCreateRequest("1", "AI_PROJECT", "管理客户端提示词配置", null);

        assertThatThrownBy(() -> service.create(project, request))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已下线");
    }

    /** DDL 确定性生成不需要业务描述（ADR 0035）。 */
    @Test
    void ddlScaffoldNeverTouchesAiAndAcceptsMissingDescription() {
        ProjectBlueprintService service = new ProjectBlueprintServiceImpl(new DdlParser(), new ObjectMapper());
        ProjectView project = new ProjectView(
                "1",
                "billing",
                "跟进后台",
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
                "DDL_SCAFFOLD",
                null,
                """
                        CREATE TABLE biz_ledger (
                          id BIGINT NOT NULL COMMENT '主键',
                          amount DECIMAL(18,2) NOT NULL COMMENT '金额',
                          PRIMARY KEY (id)
                        ) COMMENT='账目';
                        """);

        ProjectBlueprintService.ProjectBlueprint blueprint = service.create(project, request);

        assertThat(blueprint.generationMode()).isEqualTo("DDL_SCAFFOLD");
        assertThat(blueprint.aiModel()).isNull();
        assertThat(blueprint.tables()).hasSize(1);
    }
}
