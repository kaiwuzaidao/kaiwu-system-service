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
        try (var files = Files.walk(MAIN.resolve("com/kaiwu/module/operation"))) {
            offenders = files.filter(path -> path.toString().endsWith(".java"))
                    .filter(path -> path.getFileName().toString().startsWith("Audit")
                            || path.getFileName().toString().startsWith("LogCenter")
                            || path.getFileName().toString().equals("FieldChange.java")
                            || path.getFileName().toString().startsWith("LoginLog")
                            || path.getFileName().toString().startsWith("OperationLog")
                            || path.getFileName().toString().startsWith("OnlineSession"))
                    .filter(path -> source(path).contains("com.kaiwu.module.identity"))
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
        try (var files = Files.walk(MAIN.resolve("com/kaiwu/module/project"))) {
            offenders = files.filter(path -> path.toString().endsWith(".java"))
                    .filter(path -> path.getFileName().toString().startsWith("ProjectServiceCredential"))
                    .filter(path -> source(path)
                            .matches("(?s).*com\\.kaiwu\\.module\\.operation\\.[^;\\n]*Scheduler[^;\\n]*.*"))
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
                "com/kaiwu/module/identity/service/impl/AuthServiceImpl.java",
                List.of(
                        "com.kaiwu.module.operation.service.AuditService",
                        "com.kaiwu.module.configuration.service.I18nService",
                        "org.springframework.data.redis.core.StringRedisTemplate"));
        forbidden.put(
                "com/kaiwu/module/project/service/SystemPermissionSessionService.java",
                List.of(
                        "com.kaiwu.module.identity.service.AuthService",
                        "com.kaiwu.module.operation.service.NotificationService",
                        "org.springframework.data.redis.core.StringRedisTemplate"));
        forbidden.put(
                "com/kaiwu/module/project/lifecycle/SystemPermissionCutoverRunner.java",
                List.of(
                        "com.kaiwu.module.identity.service.AuthService",
                        "org.springframework.data.redis.core.StringRedisTemplate"));
        forbidden.put(
                "com/kaiwu/module/factory/service/impl/ProjectGenerationServiceImpl.java",
                List.of(
                        "com.kaiwu.module.project.repository.ProjectRepository",
                        "com.kaiwu.module.operation.service.NotificationService"));
        forbidden.put(
                "com/kaiwu/module/factory/service/impl/ProjectBlueprintServiceImpl.java",
                List.of(
                        "com.kaiwu.module.connector.service.AiProviderService",
                        "com.kaiwu.module.connector.client.OpenAiCompatibleClient"));
        forbidden.put(
                "com/kaiwu/module/operation/service/impl/ProjectSchedulerServiceImpl.java",
                List.of(
                        "com.kaiwu.module.operation.service.AuditService",
                        "com.kaiwu.module.project.repository.ProjectRepository",
                        "com.kaiwu.module.project.service.ProjectServiceCredentials"));

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
