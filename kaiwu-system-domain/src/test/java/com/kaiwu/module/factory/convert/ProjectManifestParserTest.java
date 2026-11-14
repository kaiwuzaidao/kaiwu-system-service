package com.kaiwu.module.factory.convert;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.factory.model.ProjectManifest;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * 平台资源清单的解析与校验（ADR 0036）。
 */
class ProjectManifestParserTest {

    private final ProjectManifestParser parser = new ProjectManifestParser();

    /** 三类资源都能解析；文本既可写字符串也可写多语言对象。 */
    @Test
    void parsesDictsConfigsAndMenusWithTranslations() {
        ProjectManifest manifest = parser.parse(
                Map.of(
                        "dicts.yml",
                        """
                - dictCode: order.order_status
                  name: { zh-CN: 订单状态, en-US: Order status }
                  items:
                    - { value: PAID, label: 已支付, color: success }
                    - { value: CANCELLED, label: { zh-CN: 已取消, en-US: Cancelled }, sort: 30 }
                """,
                        "configs.yml",
                        """
                - { key: order.max_items, type: NUMBER, default: 50, description: 单笔上限 }
                """,
                        "menus.yml",
                        """
                - type: MENU
                  name: 订单管理
                  path: /order
                  children:
                    - { type: BUTTON, permission: "order:order:list" }
                """));

        assertThat(manifest.dicts()).singleElement().satisfies(dict -> {
            assertThat(dict.name().translations()).containsEntry("en-US", "Order status");
            assertThat(dict.items()).extracting(ProjectManifest.DictItem::sort).containsExactly(10, 30);
            assertThat(dict.items().get(0).label().translated()).isFalse();
        });
        assertThat(manifest.configs()).singleElement().satisfies(config -> {
            assertThat(config.valueType()).isEqualTo("NUMBER");
            assertThat(config.defaultValue()).isEqualTo("50");
        });
        assertThat(manifest.menus().get(0).children())
                .singleElement()
                .satisfies(button -> assertThat(button.name().defaultText()).isEqualTo("order:order:list"));
    }

    /** 敏感配置一律拒绝，密钥不得进入仓库。 */
    @Test
    void rejectsSensitiveConfig() {
        assertThatThrownBy(() -> parser.parse(Map.of("configs.yml", "- { key: pay.api_key, default: x }")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("敏感配置");
        assertThatThrownBy(() -> parser.parse(Map.of("configs.yml", "- { key: pay.channel, secret: true }")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("敏感配置");
    }

    /** 非法文件名、重复字典值、缺权限码的按钮与 YAML 自定义类型都被拒绝。 */
    @Test
    void rejectsInvalidInput() {
        assertThatThrownBy(() -> parser.parse(Map.of("other.yml", "[]"))).hasMessageContaining("不支持的清单文件");
        assertThatThrownBy(() -> parser.parse(Map.of(
                        "dicts.yml",
                        "- { dictCode: a.b, name: x, items: [ { value: A, label: a }, { value: A, label: b } ] }")))
                .hasMessageContaining("字典值重复");
        assertThatThrownBy(() -> parser.parse(Map.of("menus.yml", "- { type: BUTTON, name: x }")))
                .hasMessageContaining("必须有 permission");
        assertThatThrownBy(() -> parser.parse(Map.of("configs.yml", "- !!java.net.URL [\"http://example.invalid\"]")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("YAML");
    }

    /** 角色清单：授权按种类解析，去重；project-admin、非 dir: 目录与重复角色被拒绝。 */
    @Test
    void parsesRolesAndRejectsInvalidOnes() {
        ProjectManifest manifest = parser.parse(
                Map.of(
                        "roles.yml",
                        """
                - roleCode: finance
                  name: 财务
                  description: 财务审批
                  permissions: [order:bill:approve, order:bill:approve]
                  routes: [/order]
                  directories: ["dir:订单"]
                """));

        assertThat(manifest.roles()).hasSize(1);
        assertThat(manifest.roles().get(0).permissions()).containsExactly("order:bill:approve");
        assertThat(manifest.roles().get(0).routes()).containsExactly("/order");
        assertThat(manifest.roles().get(0).directories()).containsExactly("dir:订单");
        assertThatThrownBy(() -> parser.parse(Map.of("roles.yml", "- { roleCode: project-admin, name: x }")))
                .hasMessageContaining("project-admin");
        assertThatThrownBy(() -> parser.parse(Map.of("roles.yml", "- { roleCode: ops, name: x, directories: [订单] }")))
                .hasMessageContaining("dir:");
        assertThatThrownBy(() ->
                        parser.parse(Map.of("roles.yml", "- { roleCode: ops, name: x }\n- { roleCode: ops, name: y }")))
                .hasMessageContaining("角色编码重复");
        assertThatThrownBy(() -> parser.parse(Map.of("roles.yml", "- { roleCode: Bad_Code, name: x }")))
                .hasMessageContaining("roleCode");
    }

    /** 文本里的 i18nKey 被解析为显式 key，且不会被当成语言代码。 */
    @Test
    void parsesExplicitI18nKeyWithoutTreatingItAsLocale() {
        ProjectManifest manifest = parser.parse(
                Map.of(
                        "dicts.yml",
                        """
                - dictCode: a.b
                  name: { i18nKey: custom.a.b, zh-CN: 名称, en-US: Name }
                  items: [ { value: A, label: a } ]
                """));

        ProjectManifest.Text name = manifest.dicts().get(0).name();
        assertThat(name.messageKey()).isEqualTo("custom.a.b");
        assertThat(name.translations()).containsOnlyKeys("en-US");
        assertThatThrownBy(
                        () -> parser.parse(
                                Map.of(
                                        "dicts.yml",
                                        "- { dictCode: a.b, name: { i18nKey: '1 bad', zh-CN: x }, items: [ { value: A, label: a } ] }")))
                .hasMessageContaining("i18nKey");
    }

    /** 定时任务清单：合法解析，Cron、时区、参数与重复任务名在解析阶段就被拒绝。 */
    @Test
    void parsesJobsAndRejectsInvalidOnes() {
        ProjectManifest manifest = parser.parse(
                Map.of(
                        "jobs.yml",
                        """
                - jobName: 日结
                  taskType: daily.settle
                  cron: "0 0 2 * * *"
                  zoneId: Asia/Shanghai
                  payload: '{"day":1}'
                  enabled: true
                """));

        assertThat(manifest.jobs()).hasSize(1);
        assertThat(manifest.jobs().get(0).payload()).isEqualTo("{\"day\":1}");
        assertThat(manifest.jobs().get(0).enabled()).isTrue();
        String base = "{ jobName: a, taskType: t, cron: '0 0 2 * * *', zoneId: Asia/Shanghai";
        assertThatThrownBy(
                        () -> parser.parse(Map.of("jobs.yml", "- { jobName: a, taskType: t, cron: bad, zoneId: UTC }")))
                .hasMessageContaining("cron");
        assertThatThrownBy(() -> parser.parse(
                        Map.of("jobs.yml", "- { jobName: a, taskType: t, cron: '0 0 2 * * *', zoneId: Mars/Base }")))
                .hasMessageContaining("zoneId");
        assertThatThrownBy(() -> parser.parse(Map.of("jobs.yml", "- " + base + ", payload: '[1]' }")))
                .hasMessageContaining("JSON 对象");
        assertThatThrownBy(() -> parser.parse(Map.of("jobs.yml", "- " + base + " }\n- " + base + " }")))
                .hasMessageContaining("任务名重复");
    }

    /** 国际化资源清单：zh-CN 必填，其余键是语言代码，重复 key 与非法语言被拒绝。 */
    @Test
    void parsesI18nMessagesAndRejectsInvalidOnes() {
        ProjectManifest manifest = parser.parse(
                Map.of(
                        "i18n.yml",
                        """
                - { messageKey: order.title, zh-CN: 订单, en-US: Orders, description: 页面标题 }
                """));

        ProjectManifest.Message message = manifest.messages().get(0);
        assertThat(message.defaultText()).isEqualTo("订单");
        assertThat(message.translations()).containsOnlyKeys("en-US");
        assertThat(message.description()).isEqualTo("页面标题");
        assertThatThrownBy(() -> parser.parse(Map.of("i18n.yml", "- { messageKey: a.b, en-US: x }")))
                .hasMessageContaining("zh-CN");
        assertThatThrownBy(() -> parser.parse(Map.of("i18n.yml", "- { messageKey: a.b, zh-CN: x, not_locale: y }")))
                .hasMessageContaining("语言代码");
        assertThatThrownBy(() -> parser.parse(
                        Map.of("i18n.yml", "- { messageKey: a.b, zh-CN: x }\n- { messageKey: a.b, zh-CN: y }")))
                .hasMessageContaining("重复");
    }
}
