package com.kaiwu.module.agent;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;

/** 平台知识会被助手当作可信说明转述给用户，里面的命令和文档路径必须真实存在。 */
class PlatformKnowledgeTest {

    private static final Path REPO_ROOT = Path.of("..").toAbsolutePath().normalize();

    @Test
    void everyLauncherCommandInKnowledgeExists() throws IOException {
        String launcher = Files.readString(REPO_ROOT.resolve("scripts/kaiwu.sh"), StandardCharsets.UTF_8);
        Set<String> commands = matches("\\./kaiwu ([a-z][a-z-]*)");

        assertThat(commands).isNotEmpty();
        assertThat(commands).allSatisfy(command -> assertThat(launcher)
                .as("scripts/kaiwu.sh 缺少命令 %s", command)
                .containsPattern("(?m)^  " + Pattern.quote(command) + "\\)"));
    }

    @Test
    void everyReferencedDocumentExists() throws IOException {
        Set<String> documents = matches("(docs/[A-Za-z0-9_-]+\\.md)");

        assertThat(documents).isNotEmpty();
        assertThat(documents).allSatisfy(document -> assertThat(REPO_ROOT.resolve(document))
                .as("知识引用的文档不存在：%s", document)
                .exists());
    }

    private static Set<String> matches(String regex) throws IOException {
        String knowledge;
        try (var in = PlatformKnowledgeTest.class.getResourceAsStream("/agent/platform-knowledge.md")) {
            knowledge = new String(in.readAllBytes(), StandardCharsets.UTF_8);
        }
        Set<String> found = new LinkedHashSet<>();
        var matcher = Pattern.compile(regex).matcher(knowledge);
        while (matcher.find()) found.add(matcher.group(1));
        return found;
    }
}
