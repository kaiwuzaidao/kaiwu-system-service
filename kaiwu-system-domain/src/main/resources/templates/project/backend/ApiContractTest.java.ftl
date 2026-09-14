package ${basePackage};

import org.junit.jupiter.api.Test;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;

import java.io.IOException;
import java.lang.annotation.Annotation;
import java.lang.reflect.Method;
import java.lang.reflect.RecordComponent;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * API 契约快照（对外接口的版本化基线）。
 *
 * <p>把已发布接口与字段作为最低兼容基线。新增接口和字段兼容放行；删除接口、删除字段、
 * 改字段类型或改已有路径会失败，避免把正常演进也误判成破坏性变更。</p>
 *
 * <p>实现上刻意只用反射读注解与 record 组件：不起 Spring 容器、不连数据库、
 * 不引 springdoc。契约的来源是源码本身，因此快照不会因为运行环境不同而漂移。</p>
 *
 * <p>确认发布新的不兼容基线时运行
 * `mvn test -Dkaiwu.api-contract.update=true`，并把快照 diff 一起提交评审。</p>
 */
class ApiContractTest {

    private static final Path SNAPSHOT = Path.of("../docs/api-contract.txt");

    /** 生成时登记的 Controller 与契约类型；新增模块要同步补进来。 */
    private static final List<Class<?>> CONTROLLERS = List.of(
<#list contractControllers as item>
            ${item}.class<#if item?has_next>,</#if>
</#list>
    );

    private static final List<Class<?>> PAYLOADS = List.of(
<#list contractPayloads as item>
            ${item}.class<#if item?has_next>,</#if>
</#list>
    );

    @Test
    void apiContractMatchesCommittedSnapshot() throws IOException {
        List<String> described = describe();
        String current = String.join("\n", described) + "\n";

        if (Boolean.getBoolean("kaiwu.api-contract.update")) {
            Files.createDirectories(SNAPSHOT.getParent());
            Files.writeString(SNAPSHOT, current);
            return;
        }

        if (!Files.exists(SNAPSHOT)) {
            Files.createDirectories(SNAPSHOT.getParent());
            Files.writeString(SNAPSHOT, current);
            throw new AssertionError(
                    "docs/api-contract.txt 缺失，已按当前源码重新生成；请检查内容后提交。");
        }

        Set<String> actual = new LinkedHashSet<>(described);
        List<String> removedOrChanged = Files.readAllLines(SNAPSHOT).stream()
                .map(String::trim)
                .filter(line -> !line.isEmpty())
                .filter(line -> !actual.contains(line))
                .toList();
        assertThat(removedOrChanged)
                .as("API 存在破坏性变化。确认发布新基线时运行 "
                        + "mvn test -Dkaiwu.api-contract.update=true 并审阅快照 diff。")
                .isEmpty();
    }

    /** 排序后的契约行，保证与运行顺序无关。 */
    private List<String> describe() {
        TreeSet<String> lines = new TreeSet<>();
        for (Class<?> controller : CONTROLLERS) {
            String base = basePath(controller);
            for (Method method : controller.getDeclaredMethods()) {
                for (String line : endpoints(base, method)) {
                    lines.add(line);
                }
            }
        }
        for (Class<?> payload : PAYLOADS) {
            for (RecordComponent component : payload.getRecordComponents()) {
                lines.add("FIELD " + payload.getSimpleName() + "."
                        + component.getName() + " : "
                        + component.getType().getSimpleName());
            }
        }
        return List.copyOf(lines);
    }

    private String basePath(Class<?> controller) {
        RequestMapping mapping = controller.getAnnotation(RequestMapping.class);
        return mapping == null || mapping.value().length == 0 ? "" : mapping.value()[0];
    }

    private List<String> endpoints(String base, Method method) {
        List<String> lines = new ArrayList<>();
        addIfPresent(lines, base, method, GetMapping.class, "GET");
        addIfPresent(lines, base, method, PostMapping.class, "POST");
        addIfPresent(lines, base, method, PutMapping.class, "PUT");
        addIfPresent(lines, base, method, PatchMapping.class, "PATCH");
        addIfPresent(lines, base, method, DeleteMapping.class, "DELETE");
        return lines;
    }

    private void addIfPresent(
            List<String> lines, String base, Method method,
            Class<? extends Annotation> annotation, String httpMethod
    ) {
        Annotation present = method.getAnnotation(annotation);
        if (present == null) {
            return;
        }
        for (String suffix : paths(present)) {
            lines.add(httpMethod + " " + base + suffix);
        }
    }

    private String[] paths(Annotation annotation) {
        try {
            String[] values = (String[]) annotation.annotationType()
                    .getMethod("value").invoke(annotation);
            return values.length == 0 ? new String[] {""} : values;
        } catch (Exception exception) {
            return new String[] {""};
        }
    }
}
