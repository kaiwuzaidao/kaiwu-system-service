package com.kaiwu.module.projectgeneration;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

class ProjectScaffoldArchitectureTest {

    private static final Path SOURCE_ROOT = Path.of("src/main/java/com/kaiwu/module/projectgeneration");

    private static final Path FRONTEND_TEMPLATES = Path.of("src/main/resources/templates/project/frontend");

    @Test
    void generatorRemainsAnOrchestratorWithFocusedRenderers() throws Exception {
        Path generator = SOURCE_ROOT.resolve("ProjectScaffoldGenerator.java");
        assertThat(Files.readAllLines(generator))
                .as("项目脚手架入口只负责编排，不应重新吸收具体仓库渲染细节")
                .hasSizeLessThanOrEqualTo(220);
        assertThat(List.of(
                        "BackendScaffoldRenderer.java",
                        "FrontendScaffoldRenderer.java",
                        "ProjectModuleRenderer.java",
                        "ScaffoldTemplateSupport.java"))
                .allSatisfy(file -> assertThat(SOURCE_ROOT.resolve(file)).exists());
    }

    /**
     * ADR 0028 §4：生成产物必须在只有公网 npm 的环境下装得上。
     *
     * <p>拦的是可验证的失败——生成项目声明了私有 scope 依赖或私有 registry 后，
     * 外部用户第一次 {@code pnpm install} 就会失败在一个他们无权访问的地址上，
     * 而失败发生在交付之后、没人盯着的时刻。</p>
     */
    @Test
    void generatedFrontendInstallsFromPublicRegistryOnly() throws Exception {
        String packageJson = Files.readString(FRONTEND_TEMPLATES.resolve("package.json.ftl"));
        assertThat(packageJson)
                .as("生成前端不得依赖 @kaiwu scope 包：该 scope 未发布到公网 npm，" + "声明它会让开源使用者的生成产物装不上（ADR 0028 §1、§2）")
                .doesNotContain("\"@kaiwu/");

        try (Stream<Path> templates = Files.list(FRONTEND_TEMPLATES)) {
            assertThat(templates.map(path -> path.getFileName().toString()))
                    .as("生成前端不得携带 .npmrc 模板：指定私有 registry 等于把开源产物" + "绑死在内网源上（ADR 0028 §1）")
                    .noneMatch(name -> name.startsWith(".npmrc") || name.equals("npmrc.ftl"));
        }
    }
}
