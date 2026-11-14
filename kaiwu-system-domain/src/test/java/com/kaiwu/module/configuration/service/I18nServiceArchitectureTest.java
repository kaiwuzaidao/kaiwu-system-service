package com.kaiwu.module.configuration.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.Test;

class I18nServiceArchitectureTest {

    private static final Path SOURCE_ROOT = Path.of("src/main/java/com/kaiwu/module/configuration/service");

    @Test
    void serviceRemainsAFacadeWithFocusedCollaborators() throws Exception {
        Path facade = SOURCE_ROOT.resolve("impl/I18nServiceImpl.java");
        assertThat(Files.readAllLines(facade))
                .as("国际化入口只负责编排和事务边界，不应重新吸收目录、消息和工作簿细节")
                .hasSizeLessThanOrEqualTo(180);
        assertThat(List.of(
                        "impl/I18nCatalogService.java",
                        "impl/I18nMessageService.java",
                        "impl/I18nWorkbookService.java"))
                .allSatisfy(file -> assertThat(SOURCE_ROOT.resolve(file)).exists());
    }
}
