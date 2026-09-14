package com.kaiwu.port;

import java.util.Map;

/** 项目工厂首次创建和推送 Git 仓库的边界。 */
public interface ProjectGenerationGitPort {

    RemoteProject requireEmptyProjectByUrl(String repositoryUrl);

    RemoteProject requireEmptyProjectById(String projectId);

    RemoteProject createEmptyProject(String groupId, String repositoryName, String description);

    String pushInitial(RemoteProject project, Map<String, String> files, String branch, String commitMessage);

    record RemoteProject(String id, String webUrl, String httpCloneUrl, String sshCloneUrl, boolean emptyRepo) {}
}
