package com.kaiwu.module.agent.presentation;

import static org.assertj.core.api.Assertions.assertThat;

import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.DataScope;
import com.kaiwu.module.agent.protocol.RedactRule;
import java.lang.reflect.Constructor;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** 出站数据治理：白名单、脱敏、截断顺序与构造入口唯一性。 */
class ResultProjectorTest {

    private final ResultProjector projector = new ResultProjector();

    private static final Capability USER_LIKE = Capability.builder("system.demo.list")
            .description("演示用能力")
            .permission("system:demo:list")
            .dataScope(DataScope.MEMBER_PROJECTS)
            .outboundFields("id", "displayName")
            .redact(Map.of("displayName", RedactRule.PARTIAL))
            .verifiedReadOnly()
            .build();

    private static Map<String, Object> row(String id, String name, String phone) {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("id", id);
        row.put("displayName", name);
        row.put("phone", phone);
        return row;
    }

    /** 未列入 outboundFields 的字段不进模型投影，但仍可出现在卡片里——两条路径边界不同。 */
    @Test
    void fieldsOutsideWhitelistNeverReachTheModelButMayStayOnTheCard() {
        List<Map<String, Object>> rows = List.of(row("1", "张三", "13800000000"));

        ModelProjection model = projector.toModel(USER_LIKE, rows);
        assertThat(model.rows()).hasSize(1);
        assertThat(model.rows().get(0)).containsOnlyKeys("id", "displayName");
        assertThat(model.rows().get(0).toString()).doesNotContain("13800000000");

        CardProjection card = projector.toCard(USER_LIKE, "演示", rows, List.of("10"));
        assertThat(card.rows().get(0)).containsKey("phone");
    }

    /** 脱敏在送模型前生效，模型只需知道存在这么一个对象。 */
    @Test
    void redactionAppliesToTheModelProjection() {
        ModelProjection model = projector.toModel(USER_LIKE, List.of(row("1", "张三", "138")));
        assertThat(model.rows().get(0)).containsEntry("displayName", "张*");
    }

    /** 截断发生在脱敏之后，最终 payload 不会出现「截了一半的敏感值」。 */
    @Test
    void truncationHappensAfterRedactionSoNoHalfMaskedValueLeaks() {
        List<Map<String, Object>> rows = new ArrayList<>();
        for (int i = 0; i < ResultProjector.MAX_MODEL_ROWS + 20; i++) {
            rows.add(row(String.valueOf(i), "姓名" + i, "1380000" + i));
        }
        ModelProjection model = projector.toModel(USER_LIKE, rows);
        assertThat(model.truncated()).isTrue();
        assertThat(model.rows()).hasSizeLessThanOrEqualTo(ResultProjector.MAX_MODEL_ROWS);
        assertThat(model.rows()).allSatisfy(r -> {
            assertThat(r).containsOnlyKeys("id", "displayName");
            assertThat(String.valueOf(r.get("displayName"))).contains("*");
        });
    }

    /** 结果里缺少白名单字段时跳过该字段，不抛错、不外发其他字段。 */
    @Test
    void absentWhitelistedFieldIsSkippedWithoutLeakingOthers() {
        Map<String, Object> incomplete = new LinkedHashMap<>();
        incomplete.put("id", "1");
        incomplete.put("phone", "13800000000");
        ModelProjection model = projector.toModel(USER_LIKE, List.of(incomplete));
        assertThat(model.rows().get(0)).containsOnlyKeys("id");
    }

    /** 未声明 outboundFields 的能力默认什么都不外发。 */
    @Test
    void capabilityWithoutOutboundFieldsSendsNothing() {
        Capability silent = Capability.builder("system.silent.list")
                .description("未声明出站字段")
                .permission("system:demo:list")
                .dataScope(DataScope.SELF)
                .verifiedReadOnly()
                .build();
        ModelProjection model = projector.toModel(silent, List.of(row("1", "张三", "138")));
        assertThat(model.rows().get(0)).isEmpty();
    }

    /**
     * 架构约定：{@link ModelProjection} 的构造函数不得公开。
     *
     * <p>类型隔离只是必要条件——把构造入口收成一个，才谈得上「唯一工厂」。</p>
     */
    @Test
    void modelProjectionConstructorIsNotPublic() {
        Constructor<?>[] constructors = ModelProjection.class.getDeclaredConstructors();
        assertThat(constructors).isNotEmpty();
        assertThat(constructors).allSatisfy(constructor -> assertThat(Modifier.isPublic(constructor.getModifiers()))
                .isFalse());
    }

    /** 卡片保留来源标记，供 P1b 按当前权限逐行过滤历史。 */
    @Test
    void cardKeepsSourceProjectsForLaterReauthorization() {
        CardProjection card = projector.toCard(USER_LIKE, "演示", List.of(row("1", "张三", "138")), List.of("10", "11"));
        assertThat(card.sourceProjects()).containsExactly("10", "11");
        assertThat(card.dataAt()).isNotNull();
    }
}
