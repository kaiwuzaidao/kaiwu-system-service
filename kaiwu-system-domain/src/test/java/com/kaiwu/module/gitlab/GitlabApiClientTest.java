package com.kaiwu.module.gitlab;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.kaiwu.common.ApiException;
import org.junit.jupiter.api.Test;

class GitlabApiClientTest {

    private final GitlabApiClient client = new GitlabApiClient(null, null);

    @Test
    void resolvesProjectPathOnlyInsideManagedGitlabOriginAndBasePath() {
        assertThat(client.projectPath(
                        "https://git.example.test/gitlab", "https://git.example.test/gitlab/team/order-service.git"))
                .isEqualTo("team/order-service");

        assertThatThrownBy(() -> client.projectPath(
                        "https://git.example.test/gitlab", "https://evil.example.test/team/order-service.git"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("平台配置");

        assertThatThrownBy(() -> client.projectPath(
                        "https://git.example.test/gitlab", "https://git.example.test/other/team/order-service.git"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("Base URL");
    }

    @Test
    void acceptsTeamConfiguredInitialBranchAndRejectsInvalidNames() {
        assertThat(GitlabApiClient.normalizeInitialBranch(" feature/ai-contract "))
                .isEqualTo("feature/ai-contract");

        assertThatThrownBy(() -> GitlabApiClient.normalizeInitialBranch("feature branch"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("分支格式");
        assertThatThrownBy(() -> GitlabApiClient.normalizeInitialBranch(" "))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("分支格式");
    }
}
