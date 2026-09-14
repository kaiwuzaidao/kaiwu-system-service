package com.kaiwu.module.projectgeneration.entity;

/** 项目远端仓库行；复合主键 {@code (project_id, repository_type)}。 */
public class ProjectRepositoryRow {

    private String projectId;
    private String repositoryType;
    private String gitlabProjectId;
    private String webUrl;
    private String httpCloneUrl;
    private String sshCloneUrl;
    private String defaultBranch;
    private String pushStatus;
    private String commitSha;
    private String lastError;

    public String getProjectId() {
        return projectId;
    }

    public void setProjectId(String projectId) {
        this.projectId = projectId;
    }

    public String getRepositoryType() {
        return repositoryType;
    }

    public void setRepositoryType(String repositoryType) {
        this.repositoryType = repositoryType;
    }

    public String getGitlabProjectId() {
        return gitlabProjectId;
    }

    public void setGitlabProjectId(String gitlabProjectId) {
        this.gitlabProjectId = gitlabProjectId;
    }

    public String getWebUrl() {
        return webUrl;
    }

    public void setWebUrl(String webUrl) {
        this.webUrl = webUrl;
    }

    public String getHttpCloneUrl() {
        return httpCloneUrl;
    }

    public void setHttpCloneUrl(String httpCloneUrl) {
        this.httpCloneUrl = httpCloneUrl;
    }

    public String getSshCloneUrl() {
        return sshCloneUrl;
    }

    public void setSshCloneUrl(String sshCloneUrl) {
        this.sshCloneUrl = sshCloneUrl;
    }

    public String getDefaultBranch() {
        return defaultBranch;
    }

    public void setDefaultBranch(String defaultBranch) {
        this.defaultBranch = defaultBranch;
    }

    public String getPushStatus() {
        return pushStatus;
    }

    public void setPushStatus(String pushStatus) {
        this.pushStatus = pushStatus;
    }

    public String getCommitSha() {
        return commitSha;
    }

    public void setCommitSha(String commitSha) {
        this.commitSha = commitSha;
    }

    public String getLastError() {
        return lastError;
    }

    public void setLastError(String lastError) {
        this.lastError = lastError;
    }
}
