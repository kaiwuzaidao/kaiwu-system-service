package com.kaiwu.module.agent.presentation;

import static org.assertj.core.api.Assertions.*;

import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.DataScope;
import com.kaiwu.module.agent.protocol.OutputViewSpec;
import com.kaiwu.module.agent.protocol.ParamSpec;
import com.kaiwu.module.agent.protocol.ParamType;
import com.kaiwu.module.agent.vo.AgentInputFormView;
import java.util.*;
import org.junit.jupiter.api.Test;

class AgentCardNavigationTest {
    private final OutputViewSpec view = new OutputViewSpec(
            "列表",
            List.of(new OutputViewSpec.Field("id", "编号", OutputViewSpec.Format.TEXT, null)),
            new OutputViewSpec.Pagination("page", "pageSize"),
            new OutputViewSpec.Detail("详情", "demo.item.detail", "itemId", "id"));

    private Capability capability(String code, boolean readOnly, Map<String, ParamSpec> params, OutputViewSpec output) {
        return new Capability(
                "demo",
                code,
                "1",
                "查询",
                "demo:item:list",
                DataScope.MEMBER_PROJECTS,
                params,
                Set.of("id"),
                Map.of(),
                readOnly,
                readOnly,
                true,
                new AgentInputFormView.Definition(
                        "title",
                        "demo:item:list",
                        params.entrySet().stream()
                                .map(entry -> new AgentInputFormView.Field(
                                        entry.getKey(),
                                        "label",
                                        entry.getValue().required(),
                                        entry.getValue().maxLength(),
                                        false,
                                        "text",
                                        entry.getValue().type().name(),
                                        entry.getValue().min(),
                                        entry.getValue().max(),
                                        null))
                                .toList()),
                output);
    }

    private Capability source() {
        return capability(
                "demo.item.list",
                true,
                Map.of(
                        "page",
                        new ParamSpec(ParamType.INT, false, 1, 1000, null, null, null, 1),
                        "pageSize",
                        ParamSpec.pageSize(20, 1),
                        "keyword",
                        ParamSpec.optionalString(30)),
                view);
    }

    private Capability target(boolean readOnly) {
        return capability(
                "demo.item.detail",
                readOnly,
                Map.of("itemId", new ParamSpec(ParamType.STRING, true, null, null, 19, null, null, null)),
                null);
    }

    @Test
    void fullPageKeepsFiltersAndLongIdsWhileEveryCommandUsesNormalInput() {
        var nav = AgentCardNavigation.build(
                source(),
                Map.of("page", 2, "pageSize", 1, "keyword", "搜索"),
                List.of(Map.of("id", "9000000000000000001")),
                false,
                List.of(target(true)));
        assertThat(nav.page()).isEqualTo(2);
        assertThat(nav.previous().values()).containsEntry("page", 1).containsEntry("keyword", "搜索");
        assertThat(nav.next().values()).containsEntry("page", 3).containsEntry("pageSize", 1);
        assertThat(nav.details().getFirst().command().values()).containsEntry("itemId", "9000000000000000001");
    }

    @Test
    void missingOrWriteTargetHasNoDetailButtonAndPartialPageHasNoNext() {
        for (var visible : List.of(List.<Capability>of(), List.of(target(false)))) {
            var nav = AgentCardNavigation.build(
                    source(), Map.of("page", 1, "pageSize", 10), List.of(Map.of("id", "1")), false, visible);
            assertThat(nav.previous()).isNull();
            assertThat(nav.next()).isNull();
            assertThat(nav.details()).isEmpty();
        }
    }

    @Test
    void emptyPageCanGoBackAndProjectionTruncationCannotSkipRows() {
        var nav = AgentCardNavigation.build(source(), Map.of("page", 2), List.of(), false, List.of());
        assertThat(nav.previous()).isNotNull();
        assertThat(nav.next()).isNull();
        assertThat(AgentCardNavigation.build(source(), Map.of(), List.of(Map.of("id", "1")), true, List.of()))
                .isNull();
    }

    @Test
    void numericIdsAreNotCoercedAndLastBoundCannotAdvance() {
        var nav = AgentCardNavigation.build(
                source(), Map.of("page", 1000), List.of(Map.of("id", 1L)), false, List.of(target(true)));
        assertThat(nav.next()).isNull();
        assertThat(nav.details()).isEmpty();
    }
}
