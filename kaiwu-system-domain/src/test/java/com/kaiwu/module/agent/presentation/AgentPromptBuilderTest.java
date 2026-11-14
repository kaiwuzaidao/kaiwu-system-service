package com.kaiwu.module.agent.presentation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.kaiwu.module.agent.planning.AgentPromptBuilder;
import com.kaiwu.module.agent.protocol.OutputViewSpec;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.metadata.vo.DictItemView;
import com.kaiwu.module.metadata.vo.EffectiveDictView;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class AgentPromptBuilderTest {

    private static final OutputViewSpec ORDER_VIEW = new OutputViewSpec(
            "订单",
            List.of(
                    new OutputViewSpec.Field("status", "状态", OutputViewSpec.Format.DICTIONARY, "order.status"),
                    new OutputViewSpec.Field("channel", "渠道", OutputViewSpec.Format.DICTIONARY, "order.channel"),
                    new OutputViewSpec.Field("amount", "金额", OutputViewSpec.Format.TEXT, null)));

    @Test
    void answerLocalizesOnlyFieldsDeclaredAsDictionaryInOutputView() {
        MetadataService metadata = mock(MetadataService.class);
        when(metadata.platformDict("order.status", "zh-CN")).thenReturn(dict("order.status", "PAID", "已支付"));
        when(metadata.platformDict("order.channel", "zh-CN")).thenReturn(dict("order.channel", "web", "网页"));
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("status", "PAID");
        row.put("channel", "web");
        row.put("amount", 42);
        ModelProjection result = ModelProjection.copyWhitelisted("order-center.order.list", List.of(row), false);

        String prompt = new AgentPromptBuilder(metadata)
                .answerUserPrompt(
                        "最近订单",
                        Map.of("order-center.order.list", result),
                        Map.of("order-center.order.list", ORDER_VIEW),
                        false,
                        "zh-CN");

        assertThat(prompt).contains("status=已支付", "channel=网页", "amount=42");
        assertThat(prompt).doesNotContain("PAID", "channel=web");
        assertThat(row).containsEntry("status", "PAID").containsEntry("channel", "web");
    }

    @Test
    void unknownValueAndCapabilityWithoutViewRemainUnchanged() {
        MetadataService metadata = mock(MetadataService.class);
        when(metadata.platformDict("order.status", "en-US")).thenReturn(dict("order.status", "PAID", "Paid"));
        when(metadata.platformDict("order.channel", "en-US")).thenReturn(dict("order.channel", "app", "App"));
        ModelProjection orders = ModelProjection.copyWhitelisted(
                "order-center.order.list", List.of(Map.of("status", "NEW_STATUS", "channel", "app")), false);
        ModelProjection other =
                ModelProjection.copyWhitelisted("system.project.list", List.of(Map.of("status", "PAID")), false);

        String prompt = new AgentPromptBuilder(metadata)
                .answerUserPrompt(
                        "recent orders",
                        Map.of("order-center.order.list", orders, "system.project.list", other),
                        Map.of("order-center.order.list", ORDER_VIEW),
                        false,
                        "en-US");

        assertThat(prompt).contains("status=NEW_STATUS", "channel=App", "status=PAID");
    }

    @Test
    void remoteAnswerUsesProjectDictionaryAndUserMembership() {
        MetadataService metadata = mock(MetadataService.class);
        when(metadata.effectiveDict("42", "order.status", "7", "zh-CN"))
                .thenReturn(dict("order.status", "PAID", "项目已支付"));
        when(metadata.effectiveDict("42", "order.channel", "7", "zh-CN"))
                .thenReturn(dict("order.channel", "web", "项目网页"));
        ModelProjection result = ModelProjection.copyWhitelisted(
                "order-center.order.list", List.of(Map.of("status", "PAID", "channel", "web")), false);
        String prompt = new AgentPromptBuilder(metadata)
                .answerUserPrompt(
                        "订单",
                        Map.of("order-center.order.list", result),
                        Map.of("order-center.order.list", ORDER_VIEW),
                        Map.of("order-center.order.list", "42"),
                        "7",
                        false,
                        "zh-CN");
        assertThat(prompt).contains("status=项目已支付", "channel=项目网页");
    }

    @Test
    void answerPromptCarriesVersionedPlatformKnowledge() {
        String prompt = new AgentPromptBuilder(mock(MetadataService.class)).answerSystemPrompt("zh-CN", List.of());

        assertThat(prompt).contains("【平台知识】", "./kaiwu project-up", "以【平台知识】为准");
    }

    @Test
    void planningPromptLetsModelDraftProjectFieldsForReviewInForm() {
        String prompt = new AgentPromptBuilder(mock(MetadataService.class))
                .planningSystemPrompt(List.of(), java.util.Set.of(), List.of());

        assertThat(prompt).contains("为它起草参数", "表单会把起草值交给用户核对修改", "calls 返回空数组，由回答阶段依据平台知识作答");
    }

    private static EffectiveDictView dict(String code, String value, String label) {
        return new EffectiveDictView(
                code, code, null, List.of(new DictItemView("1", label, value, 0, false, null, null, null, "ENABLED")));
    }
}
