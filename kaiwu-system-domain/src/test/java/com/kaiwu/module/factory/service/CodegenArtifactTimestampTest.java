package com.kaiwu.module.factory.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.kaiwu.module.factory.service.impl.CodegenArtifactServiceImpl;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import java.util.zip.ZipFile;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/** 覆盖用户直接下载的 ZIP，避免生成模板的普通工作树掩盖制品时间问题。 */
class CodegenArtifactTimestampTest {

    /** 同样的输入必须逐字节相同，每个资源的时间又要晚于 Maven 对缺失目标使用的零时间。 */
    @Test
    void packagesReproducibleResourcesWithUsableTimestamps(@TempDir Path root) throws Exception {
        var artifacts = new CodegenArtifactServiceImpl(root.toString());
        var files = Map.of("src/main/resources/application.yml", "spring: {}", "README.md", "project");
        Path first = root.resolve(artifacts.createProjectArtifact("a", "backend", "demo", files));
        Path second = root.resolve(artifacts.createProjectArtifact("b", "backend", "demo", files));

        assertThat(Files.mismatch(first, second)).isEqualTo(-1);
        try (var zip = new ZipFile(first.toFile())) {
            for (String name : files.keySet()) {
                assertThat(zip.getEntry(name).getTime()).isPositive();
            }
        }
    }
}
