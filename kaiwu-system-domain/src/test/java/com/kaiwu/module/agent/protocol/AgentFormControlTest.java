package com.kaiwu.module.agent.protocol;

import static org.assertj.core.api.Assertions.*;

import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;

class AgentFormControlTest {
    @Test
    void acceptsReviewedEnumAndLocalDateTimeControls() {
        var params = Map.of(
                "status", ParamSpec.optionalEnum(Set.of("ACTIVE", "DISABLED")), "since", ParamSpec.optionalDateTime());
        var form = new InputFormSpec(
                "筛选记录",
                List.of(
                        new InputFormSpec.Field("status", "状态", false, "common.status"),
                        new InputFormSpec.Field("since", "开始时间", false)));
        assertThatCode(() -> form.validate(params)).doesNotThrowAnyException();
    }

    @Test
    void rejectsMissingDictionaryAndDictionaryOnTextAndMultilineDate() {
        for (String dictionary : new String[] {null, "https://example.com", "common.status?admin=true"}) {
            var form = new InputFormSpec("查询", List.of(new InputFormSpec.Field("status", "状态", false, dictionary)));
            assertThatThrownBy(() -> form.validate(Map.of("status", ParamSpec.optionalEnum(Set.of("ACTIVE")))))
                    .isInstanceOf(IllegalArgumentException.class);
        }
        assertThatThrownBy(() -> new InputFormSpec(
                                "查询", List.of(new InputFormSpec.Field("name", "名称", false, "common.status")))
                        .validate(Map.of("name", ParamSpec.optionalString(100))))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new InputFormSpec("查询", List.of(new InputFormSpec.Field("since", "时间", true)))
                        .validate(Map.of("since", ParamSpec.optionalDateTime())))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
