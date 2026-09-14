package com.kaiwu.common;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static org.assertj.core.api.Assertions.assertThat;

import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.lang.ArchRule;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

/**
 * 把 CLAUDE.md / AGENTS.md 里的架构约束翻译成可执行断言。
 *
 * <p>存在的意义：ADR 0017 的起因不是「JdbcTemplate 不好」，而是**一条写进「不可变架构」的
 * 约束被违反了，且没有任何环节发现**。写在 Markdown 里的「必须 / 不得」只是意图；
 * 只有能让构建变红的才是约束。</p>
 *
 * <p>这里只收录**本仓库真实发生过或明确写进契约**的规则，不引入通用最佳实践清单——
 * 规则本身也有维护成本，与项目无关的告警会让人学会忽略红灯。</p>
 */
class ArchitectureConventionTest {

    private static JavaClasses productionClasses;

    @BeforeAll
    static void importClasses() {
        productionClasses = new ClassFileImporter()
                .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
                .importPackages("com.kaiwu");
    }

    // 「模块依赖固定为 boot -> domain -> api」不在这里检查：api 与 domain 共用同一套包前缀
    // （com.kaiwu.module.* 两边都有），ArchUnit 按包名分不出模块；而这条约束 Maven 在编译期
    // 已经强制了——api 的 pom 里根本没有 domain 依赖，反向引用直接编译失败。
    // 与其留一条名字唬人、实际检查别的东西的规则，不如不留。

    /**
     * Controller 不得直接依赖 Mapper。
     *
     * <p>Mapper 返回的是贴着表结构的实体，Controller 直接用它意味着表结构泄露进 HTTP 契约，
     * 改一次列名就要改前端。中间必须隔一层 Service/Repository 做视图转换。</p>
     */
    @Test
    void controllersNeverTouchMappersDirectly() {
        ArchRule rule = noClasses()
                .that()
                .haveSimpleNameEndingWith("Controller")
                .should()
                .dependOnClassesThat()
                .resideInAPackage("..mapper..")
                .because("Controller 必须经 Service/Repository，不得直接访问数据层");
        rule.check(productionClasses);
    }

    /**
     * 数据层只用 MyBatis-Plus（ADR 0017）。
     *
     * <p>取代原先的文本扫描版：ArchUnit 看的是编译后的真实依赖，重命名、静态导入、
     * 全限定名写法都绕不过去。</p>
     */
    @Test
    void dataAccessNeverUsesJdbcTemplateOrASecondOrm() {
        ArchRule rule = noClasses()
                .that()
                .resideInAPackage("com.kaiwu..")
                .should()
                .dependOnClassesThat()
                .resideInAnyPackage(
                        "org.springframework.jdbc..", "jakarta.persistence..", "org.hibernate..", "org.jooq..")
                .because("平台数据层统一为 MyBatis-Plus（ADR 0017/0020）；" + "单表 CRUD 走 BaseMapper，复杂查询可使用 Mapper XML");
        rule.check(productionClasses);
    }

    /**
     * 一张表只有一份实体（AGENTS.md）。
     *
     * <p>同一张表两份实体是迁移过程中最容易埋的漂移源：改了一处忘另一处，
     * 两边对同一行数据的理解就分叉了。用 {@code @TableName} 的值判重。</p>
     */
    @Test
    void eachTableHasExactlyOneEntity() {
        Map<String, List<String>> byTable = new HashMap<>();
        for (JavaClass type : productionClasses) {
            type.tryGetAnnotationOfType(com.baomidou.mybatisplus.annotation.TableName.class)
                    .ifPresent(annotation -> byTable.computeIfAbsent(annotation.value(), ignored -> new ArrayList<>())
                            .add(type.getName()));
        }
        List<String> duplicated = byTable.entrySet().stream()
                .filter(entry -> entry.getValue().size() > 1)
                .map(entry -> entry.getKey() + " -> " + entry.getValue())
                .sorted()
                .toList();

        assertThat(duplicated)
                .withFailMessage("以下表有多份 @TableName 实体，违反「一张表一份实体」：%s", duplicated)
                .isEmpty();
    }

    /**
     * 实体不得出现在 Controller 的返回值里。
     *
     * <p>与上一条同源：实体贴表结构，VO 是对外契约。直接返回实体会让表的每次演进
     * 都变成一次前端破坏性变更，也容易顺手把不该外发的列（如密码哈希）带出去。</p>
     */
    @Test
    void controllersNeverReturnEntities() {
        List<String> offenders = new ArrayList<>();
        for (JavaClass type : productionClasses) {
            if (!type.getSimpleName().endsWith("Controller")) continue;
            type.getMethods().stream()
                    .filter(method -> method.getModifiers().stream()
                            .anyMatch(modifier -> modifier.name().equals("PUBLIC")))
                    .forEach(method -> {
                        String signature = method.getFullName();
                        method.getReturnType().toErasure().getAllInvolvedRawTypes().stream()
                                .filter(raw -> raw.isAnnotatedWith(com.baomidou.mybatisplus.annotation.TableName.class))
                                .findFirst()
                                .ifPresent(raw -> offenders.add(signature + " -> " + raw.getName()));
                    });
        }
        assertThat(offenders)
                .withFailMessage("以下 Controller 方法直接返回了数据库实体，表结构会泄露进 HTTP 契约：%s", offenders)
                .isEmpty();
    }

    /**
     * 审计与通知等横切能力不得被 api 模块反向依赖。
     *
     * <p>api 是纯契约模块，一旦依赖 domain 的服务，生成项目引用 api 就会被迫拖上整个平台实现。</p>
     */
    @Test
    void contractTypesStayFreeOfSpringWiring() {
        ArchRule rule = noClasses()
                .that()
                .resideInAPackage("com.kaiwu.module..")
                .and()
                .haveSimpleNameEndingWith("Request")
                .should()
                .dependOnClassesThat()
                .resideInAnyPackage("org.springframework.stereotype..", "..mapper..")
                .because("DTO 是稳定契约，不该携带 Spring 装配或数据层依赖");
        rule.check(productionClasses);
    }
}
