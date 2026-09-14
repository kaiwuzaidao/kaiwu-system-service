package com.kaiwu.module.projectgeneration;

import com.kaiwu.module.gitlab.GitlabApiClient;
import com.kaiwu.port.ProjectGenerationGitPort;
import java.util.Map;
import org.springframework.stereotype.Component;

/** 项目工厂到受管 GitLab 客户端的适配器。 */
@Component
public class ProjectGenerationGitAdapter implements ProjectGenerationGitPort {

    private final GitlabApiClient client;

    public ProjectGenerationGitAdapter(GitlabApiClient client) {
        this.client = client;
    }

    @Override
    public RemoteProject requireEmptyProjectByUrl(String repositoryUrl) {
        return remote(client.requireEmptyProjectByUrl(repositoryUrl));
    }

    @Override
    public RemoteProject requireEmptyProjectById(String projectId) {
        return remote(client.requireEmptyProjectById(projectId));
    }

    @Override
    public RemoteProject createEmptyProject(String groupId, String repositoryName, String description) {
        return remote(client.createEmptyProject(groupId, repositoryName, description));
    }

    @Override
    public String pushInitial(RemoteProject project, Map<String, String> files, String branch, String commitMessage) {
        GitlabApiClient.RemoteProject remote = new GitlabApiClient.RemoteProject(
                project.id(), project.webUrl(), project.httpCloneUrl(), project.sshCloneUrl(), project.emptyRepo());
        return client.pushInitial(remote, files, branch, commitMessage).commitSha();
    }

    private static RemoteProject remote(GitlabApiClient.RemoteProject project) {
        return new RemoteProject(
                project.id(), project.webUrl(), project.httpCloneUrl(), project.sshCloneUrl(), project.emptyRepo());
    }
}
