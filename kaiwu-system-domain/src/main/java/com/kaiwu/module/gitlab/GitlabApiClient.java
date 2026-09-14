package com.kaiwu.module.gitlab;

import com.kaiwu.common.ApiException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * GitLab REST 客户端。Token 只发往受管 Base URL 的同源 API。
 */
@Component
public class GitlabApiClient {

    private final GitlabConfigService configService;
    private final ObjectMapper objectMapper;

    public GitlabApiClient(GitlabConfigService configService, ObjectMapper objectMapper) {
        this.configService = configService;
        this.objectMapper = objectMapper;
    }

    /** 用当前配置访问 GitLab 当前用户接口，验证地址与令牌是否可用。 */
    public TestResult testConnection() {
        GitlabConfigService.RuntimeConfig config = configService.requireEnabled();
        JsonNode body = request(config, "GET", "/api/v4/user", null);
        String username = body.path("username").asText("");
        return new TestResult(StringUtils.hasText(username) ? "GitLab 连接成功，当前用户：" + username : "GitLab 连接成功");
    }

    public RemoteProject requireEmptyProjectByUrl(String repositoryUrl) {
        GitlabConfigService.RuntimeConfig config = configService.requireEnabled();
        String projectPath = projectPath(config.baseUrl(), repositoryUrl);
        return requireEmpty(config, encode(projectPath));
    }

    public RemoteProject requireEmptyProjectById(String projectId) {
        GitlabConfigService.RuntimeConfig config = configService.requireEnabled();
        return requireEmpty(config, encode(projectId));
    }

    /** 在指定群组下创建空仓库；仓库已存在时返回既有项目，不覆盖其内容。 */
    public RemoteProject createEmptyProject(String groupId, String repositoryName, String description) {
        GitlabConfigService.RuntimeConfig config = configService.requireEnabled();
        String effectiveGroup = StringUtils.hasText(groupId) ? groupId.trim() : config.defaultGroupId();
        if (!StringUtils.hasText(effectiveGroup) || !effectiveGroup.matches("^\\d+$")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "创建 GitLab 仓库需要配置数值 Group ID", "api.common.badRequest");
        }
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("name", repositoryName);
        body.put("path", repositoryName);
        body.put("namespace_id", Long.parseLong(effectiveGroup));
        body.put("visibility", "private");
        body.put("initialize_with_readme", false);
        body.put("description", description);
        return remote(request(config, "POST", "/api/v4/projects", body));
    }

    /**
     * 向空仓库执行一次初始提交。
     *
     * <p>只允许一次、禁止 force push（CLAUDE.md 工程约束第 11 条）：推之前确认远端为空，
     * 非空则拒绝，避免覆盖别人已有的代码。</p>
     */
    public PushResult pushInitial(
            RemoteProject project, Map<String, String> files, String branch, String commitMessage) {
        String initialBranch = normalizeInitialBranch(branch);
        GitlabConfigService.RuntimeConfig config = configService.requireEnabled();
        RemoteProject checked = requireEmpty(config, encode(project.id()));
        if (!checked.id().equals(project.id())) {
            throw new ApiException(HttpStatus.CONFLICT, "GitLab 项目标识已变化", "api.common.conflict");
        }
        List<Map<String, Object>> actions = new ArrayList<>();
        files.entrySet().stream()
                .sorted(Map.Entry.comparingByKey())
                .forEach(entry -> actions.add(Map.of(
                        "action",
                        "create",
                        "file_path",
                        entry.getKey(),
                        "content",
                        entry.getValue(),
                        "encoding",
                        "text")));
        if (actions.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "生成制品中没有可推送文件", "api.common.badRequest");
        }
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("branch", initialBranch);
        body.put("commit_message", commitMessage);
        body.put("actions", actions);
        JsonNode result =
                request(config, "POST", "/api/v4/projects/" + encode(project.id()) + "/repository/commits", body);
        String commitSha = result.path("id").asText("");
        if (!StringUtils.hasText(commitSha)) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "GitLab 未返回提交 SHA", "api.common.upstreamFailed");
        }
        return new PushResult(commitSha);
    }

    static String normalizeInitialBranch(String branch) {
        if (!StringUtils.hasText(branch) || !branch.trim().matches("^[A-Za-z0-9._/-]{1,64}$")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Git 初始分支格式不正确", "api.common.badRequest");
        }
        return branch.trim();
    }

    private RemoteProject requireEmpty(GitlabConfigService.RuntimeConfig config, String encodedId) {
        RemoteProject project = remote(request(config, "GET", "/api/v4/projects/" + encodedId, null));
        if (!project.emptyRepo()) {
            throw new ApiException(HttpStatus.CONFLICT, "指定 GitLab 仓库不是空仓库，Kaiwu 不会覆盖已有代码", "api.common.conflict");
        }
        return project;
    }

    private RemoteProject remote(JsonNode body) {
        String id = body.path("id").asText("");
        String webUrl = body.path("web_url").asText("");
        if (!StringUtils.hasText(id) || !StringUtils.hasText(webUrl)) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "GitLab 项目信息不完整", "api.common.upstreamFailed");
        }
        return new RemoteProject(
                id,
                webUrl,
                body.path("http_url_to_repo").asText(null),
                body.path("ssh_url_to_repo").asText(null),
                body.path("empty_repo").asBoolean(true));
    }

    /**
     * 只读取仓库中一个已知路径的文本文件，用于 ADR 0012 的项目体检。
     *
     * <p>只允许读，不遍历目录树，也不 clone；文件不存在返回 {@code Optional.empty()} 而不是
     * 抛异常——「文件被删掉」正是体检要报告的结论之一，不是调用失败。GitLab 不可达仍然抛
     * 异常，由调用方区分「确认缺失」和「无法确认」。</p>
     *
     * @param gitlabProjectId GitLab 项目 ID 或 URL 编码后的 namespace/project
     * @param ref             分支或提交
     * @param filePath        仓库内相对路径，如 {@code docs/kaiwu-project-blueprint.json}
     */
    public Optional<String> readTextFile(String gitlabProjectId, String ref, String filePath) {
        GitlabConfigService.RuntimeConfig config = configService.requireEnabled();
        String path = "/api/v4/projects/" + encode(gitlabProjectId)
                + "/repository/files/" + encode(filePath)
                + "/raw?ref=" + encode(ref);
        try {
            URI uri = URI.create(config.baseUrl() + path);
            requireSameOrigin(config.baseUrl(), uri);
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(uri)
                    .timeout(Duration.ofSeconds(30))
                    .header("PRIVATE-TOKEN", config.token())
                    .GET()
                    .build();
            HttpResponse<String> response = HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(10))
                    .followRedirects(HttpClient.Redirect.NEVER)
                    .build()
                    .send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() == 404) {
                return Optional.empty();
            }
            if (response.statusCode() / 100 != 2) {
                throw new ApiException(
                        HttpStatus.BAD_GATEWAY,
                        "GitLab 读取文件失败（HTTP " + response.statusCode() + "）",
                        "api.common.upstreamFailed");
            }
            return Optional.ofNullable(response.body());
        } catch (ApiException exception) {
            throw exception;
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new ApiException(HttpStatus.BAD_GATEWAY, "GitLab 请求被中断", "api.common.upstreamFailed");
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "GitLab 不可达或响应无效", "api.common.upstreamFailed");
        }
    }

    private JsonNode request(GitlabConfigService.RuntimeConfig config, String method, String path, Object body) {
        try {
            URI uri = URI.create(config.baseUrl() + path);
            requireSameOrigin(config.baseUrl(), uri);
            HttpRequest.Builder builder = HttpRequest.newBuilder()
                    .uri(uri)
                    .timeout(Duration.ofSeconds(30))
                    .header("PRIVATE-TOKEN", config.token())
                    .header("Accept", "application/json");
            if (body == null) {
                builder.method(method, HttpRequest.BodyPublishers.noBody());
            } else {
                builder.header("Content-Type", "application/json")
                        .method(method, HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(body)));
            }
            HttpResponse<String> response = HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(10))
                    .followRedirects(HttpClient.Redirect.NEVER)
                    .build()
                    .send(builder.build(), HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() / 100 != 2) {
                throw new ApiException(
                        HttpStatus.BAD_GATEWAY,
                        "GitLab 请求失败（HTTP " + response.statusCode() + "）",
                        "api.common.upstreamFailed");
            }
            return objectMapper.readTree(response.body());
        } catch (ApiException exception) {
            throw exception;
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new ApiException(HttpStatus.BAD_GATEWAY, "GitLab 请求被中断", "api.common.upstreamFailed");
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "GitLab 不可达或响应无效", "api.common.upstreamFailed");
        }
    }

    String projectPath(String baseUrl, String repositoryUrl) {
        try {
            URI configured = URI.create(baseUrl);
            URI requested = URI.create(repositoryUrl);
            requireSameOrigin(baseUrl, requested);
            String basePath = normalizePath(configured.getPath());
            String requestedPath = normalizePath(requested.getPath());
            if (!"/".equals(basePath)) {
                if (!requestedPath.startsWith(basePath + "/")) {
                    throw new ApiException(
                            HttpStatus.BAD_REQUEST, "GitLab 仓库地址不在受管 Base URL 路径下", "api.common.badRequest");
                }
                requestedPath = requestedPath.substring(basePath.length());
            }
            String projectPath = requestedPath.replaceFirst("^/", "").replaceFirst("\\.git$", "");
            if (projectPath.isBlank() || !projectPath.contains("/")) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST, "GitLab 仓库地址必须包含 namespace/project", "api.common.badRequest");
            }
            return projectPath;
        } catch (ApiException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "GitLab 仓库地址格式不正确", "api.common.badRequest");
        }
    }

    private void requireSameOrigin(String baseUrl, URI requested) {
        URI configured = URI.create(baseUrl);
        int configuredPort = configured.getPort() >= 0 ? configured.getPort() : defaultPort(configured.getScheme());
        int requestedPort = requested.getPort() >= 0 ? requested.getPort() : defaultPort(requested.getScheme());
        if (requested.getUserInfo() != null
                || !configured.getScheme().equalsIgnoreCase(requested.getScheme())
                || configured.getHost() == null
                || requested.getHost() == null
                || !configured.getHost().equalsIgnoreCase(requested.getHost())
                || configuredPort != requestedPort) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "GitLab 仓库地址必须属于平台配置的 GitLab 实例", "api.common.badRequest");
        }
    }

    private static int defaultPort(String scheme) {
        return "https".equalsIgnoreCase(scheme) ? 443 : 80;
    }

    private static String normalizePath(String value) {
        if (!StringUtils.hasText(value) || "/".equals(value)) return "/";
        return value.replaceAll("/+$", "");
    }

    private static String encode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }

    public record RemoteProject(String id, String webUrl, String httpCloneUrl, String sshCloneUrl, boolean emptyRepo) {}

    public record PushResult(String commitSha) {}

    public record TestResult(String message) {}
}
