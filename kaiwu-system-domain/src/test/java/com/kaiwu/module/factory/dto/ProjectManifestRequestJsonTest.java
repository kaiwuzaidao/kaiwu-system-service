package com.kaiwu.module.factory.dto;

import static org.assertj.core.api.Assertions.assertThat;

import com.kaiwu.module.factory.vo.ProjectManifestPlanView;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

/** 页面发来的 JSON 能反序列化为请求对象（ADR 0042）。 */
class ProjectManifestRequestJsonTest {

    /** 导入预览：只带 files 与来源信息，不带计划哈希与勾选。 */
    @Test
    void planBodyFromThePageDeserializes() {
        String json =
                """
                {"files":{"dicts.yml":"","roles.yml":"- { roleCode: a, name: b }"},
                 "packageDigest":"387b90a9eda33c6a56dc3fe921662e3b632d5ee5c9c42bfd20e76965afaf1eb4",
                 "sourceHost":"kaiwu-kaiwu-system","sourceExportedBy":"1",
                 "sourceExportedAt":"2026-10-30T06:04:53.900833828Z"}
                """;

        ProjectManifestRequest request = JsonMapper.builder().build().readValue(json, ProjectManifestRequest.class);

        assertThat(request.files()).containsKey("roles.yml");
        assertThat(request.packageDigest()).hasSize(64);
        assertThat(request.deleteKeys()).isEmpty();
        assertThat(request.applyAccess()).isFalse();
    }

    /** 执行：带计划哈希、授权开关与勾选的删除项。 */
    @Test
    void applyBodyFromThePageDeserializes() {
        String json =
                """
                {"files":{"configs.yml":"- { key: a.b }"},"planHash":"h","applyAccess":true,
                 "deleteKeys":["CONFIG|a.old"],"packageDigest":"d"}
                """;

        ProjectManifestRequest request = JsonMapper.builder().build().readValue(json, ProjectManifestRequest.class);

        assertThat(request.applyAccess()).isTrue();
        assertThat(request.deleteKeys()).containsExactly("CONFIG|a.old");
        assertThat(request.planHash()).isEqualTo("h");
    }

    /** 移交记录把计划条目存成 JSON 再读回，带两个构造器的 record 也能还原。 */
    @Test
    void planChangesRoundTripThroughJson() {
        JsonMapper mapper = JsonMapper.builder().build();
        java.util.List<ProjectManifestPlanView.Change> changes = java.util.List.of(
                new ProjectManifestPlanView.Change("DICT", "a.b", "CREATE", "新增"),
                new ProjectManifestPlanView.Change("CONFIG", "a.old", "REMOVED_AT_SOURCE", "已删除", "DELETE"));

        java.util.List<ProjectManifestPlanView.Change> back = mapper.readValue(
                mapper.writeValueAsString(changes),
                new tools.jackson.core.type.TypeReference<java.util.List<ProjectManifestPlanView.Change>>() {});

        assertThat(back).isEqualTo(changes);
        assertThat(back.get(0).category()).isEqualTo("NORMAL");
        assertThat(back.get(1).category()).isEqualTo("DELETE");
    }
}
