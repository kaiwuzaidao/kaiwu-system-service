package com.kaiwu.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * 模块依赖方向门禁：应用服务通过 {@code com.kaiwu.port} 使用跨模块能力。
 *
 * <p>该测试不追求把模块化单体伪装成独立微服务，只拦截最容易形成环依赖的核心服务。
 * Mapper、Entity 和模块内部协作者不受此规则影响。</p>
 */
class ModuleDependencyArchitectureTest {

    private static final Path MAIN = Path.of("src/main/java");

    @Test
    void auditNeverDependsOnAuthenticationImplementation() throws IOException {
        List<String> offenders;
        try (var files = Files.walk(MAIN.resolve("com/kaiwu/module/audit"))) {
            offenders = files.filter(path -> path.toString().endsWith(".java"))
                    .filter(path -> source(path).contains("com.kaiwu.module.auth"))
                    .map(MAIN::relativize)
                    .map(Path::toString)
                    .sorted()
                    .toList();
        }

        assertThat(offenders)
                .withFailMessage("audit 不得反向依赖 auth，实现会话撤销应通过 Port：%s", offenders)
                .isEmpty();
    }

    @Test
    void credentialAuthenticationNeverDependsOnSchedulerImplementation() throws IOException {
        List<String> offenders;
        try (var files = Files.walk(MAIN.resolve("com/kaiwu/module/credential"))) {
            offenders = files.filter(path -> path.toString().endsWith(".java"))
                    .filter(path -> source(path).contains("com.kaiwu.module.scheduler"))
                    .map(MAIN::relativize)
                    .map(Path::toString)
                    .sorted()
                    .toList();
        }

        assertThat(offenders)
                .withFailMessage("凭据认证不得反向依赖 scheduler Mapper，应通过存储 Port：%s", offenders)
                .isEmpty();
    }

    @Test
    void coreApplicationServicesUsePortsForCrossModuleCapabilities() {
        Map<String, List<String>> forbidden = new LinkedHashMap<>();
        forbidden.put(
                "com/kaiwu/module/auth/AuthService.java",
                List.of(
                        "com.kaiwu.module.audit.AuditService",
                        "com.kaiwu.module.i18n.I18nService",
                        "org.springframework.data.redis.core.StringRedisTemplate"));
        forbidden.put(
                "com/kaiwu/module/project/SystemPermissionSessionService.java",
                List.of(
                        "com.kaiwu.module.auth.AuthService",
                        "com.kaiwu.module.notification.NotificationService",
                        "org.springframework.data.redis.core.StringRedisTemplate"));
        forbidden.put(
                "com/kaiwu/module/project/SystemPermissionCutoverRunner.java",
                List.of(
                        "com.kaiwu.module.auth.AuthService",
                        "org.springframework.data.redis.core.StringRedisTemplate"));
        forbidden.put(
                "com/kaiwu/module/projectgeneration/ProjectGenerationService.java",
                List.of(
                        "com.kaiwu.module.project.ProjectRepository",
                        "com.kaiwu.module.gitlab.GitlabApiClient",
                        "com.kaiwu.module.notification.NotificationService"));
        forbidden.put(
                "com/kaiwu/module/projectgeneration/ProjectBlueprintService.java",
                List.of("com.kaiwu.module.ai.AiProviderService", "com.kaiwu.module.ai.OpenAiCompatibleClient"));
        forbidden.put(
                "com/kaiwu/module/scheduler/ProjectSchedulerService.java",
                List.of(
                        "com.kaiwu.module.audit.AuditService",
                        "com.kaiwu.module.project.ProjectRepository",
                        "com.kaiwu.module.credential.ProjectServiceCredentials"));

        Map<String, List<String>> offenders = new LinkedHashMap<>();
        forbidden.forEach((relative, types) -> {
            String content = source(MAIN.resolve(relative));
            List<String> found = types.stream().filter(content::contains).toList();
            if (!found.isEmpty()) {
                offenders.put(relative, found);
            }
        });

        assertThat(offenders)
                .withFailMessage("核心应用服务存在跨模块具体实现依赖，应改为窄 Port：%s", offenders)
                .isEmpty();
    }

    private static String source(Path path) {
        try {
            return Files.readString(path);
        } catch (IOException exception) {
            throw new IllegalStateException("无法读取源码：" + path, exception);
        }
    }
}
