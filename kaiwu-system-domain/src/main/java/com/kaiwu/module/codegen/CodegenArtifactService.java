package com.kaiwu.module.codegen;

import com.kaiwu.common.ApiException;
import java.io.BufferedOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
public class CodegenArtifactService {

    private final Path artifactRoot;

    public CodegenArtifactService(@Value("${kaiwu.codegen.artifact-root:/var/lib/kaiwu/artifacts}") String root) {
        artifactRoot = Path.of(root).toAbsolutePath().normalize();
    }

    public String create(String taskNo, Map<String, String> files) {
        String artifactName = taskNo + ".zip";
        write(artifactName, files);
        return artifactName;
    }

    /** 把生成的文件打成压缩包落盘，返回制品名；制品名不含路径，避免目录穿越。 */
    public String createProjectArtifact(
            String taskNo, String repositoryType, String projectCode, Map<String, String> files) {
        String artifactName = taskNo + "-" + repositoryType.toLowerCase(Locale.ROOT) + "-" + projectCode + ".zip";
        write(artifactName, files);
        return artifactName;
    }

    private void write(String artifactName, Map<String, String> files) {
        Path target = resolve(artifactName);
        try {
            Files.createDirectories(artifactRoot);
            try (ZipOutputStream zip = new ZipOutputStream(
                    new BufferedOutputStream(Files.newOutputStream(target)), StandardCharsets.UTF_8)) {
                for (Map.Entry<String, String> entry : new TreeMap<>(files).entrySet()) {
                    String path = safeEntry(entry.getKey());
                    ZipEntry zipEntry = new ZipEntry(path);
                    zipEntry.setTime(0L);
                    zip.putNextEntry(zipEntry);
                    zip.write(entry.getValue().getBytes(StandardCharsets.UTF_8));
                    zip.closeEntry();
                }
            }
        } catch (IOException exception) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "生成 ZIP 失败", "api.common.internalError");
        }
    }

    /** 按制品名取回可下载资源；文件不存在时抛出而不是返回空流。 */
    public Resource resource(String artifactName) {
        Path path = resolve(artifactName);
        if (!Files.isRegularFile(path)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "生成制品不存在", "api.common.notFound");
        }
        return new FileSystemResource(path);
    }

    /** 读回制品内的全部文件，供推送 GitLab 时逐个提交。 */
    public Map<String, String> readFiles(String artifactName) {
        Path path = resolve(artifactName);
        if (!Files.isRegularFile(path)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "生成制品不存在", "api.common.notFound");
        }
        Map<String, String> files = new TreeMap<>();
        try (ZipInputStream zip = new ZipInputStream(Files.newInputStream(path), StandardCharsets.UTF_8)) {
            ZipEntry entry;
            while ((entry = zip.getNextEntry()) != null) {
                String name = safeEntry(entry.getName());
                files.put(name, new String(zip.readAllBytes(), StandardCharsets.UTF_8));
                zip.closeEntry();
            }
            return files;
        } catch (IOException exception) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "读取 ZIP 失败", "api.common.internalError");
        }
    }

    /** 尽力删除制品；失败不抛出——清理失败不该让主流程失败。 */
    public void deleteQuietly(String artifactName) {
        try {
            Files.deleteIfExists(resolve(artifactName));
        } catch (IOException ignored) {
            // 数据库写入失败时尽力清理孤儿制品，清理失败不覆盖原异常。
        }
    }

    private Path resolve(String artifactName) {
        if (!artifactName.matches("[A-Za-z0-9._-]+\\.zip")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "制品名称不合法", "api.common.badRequest");
        }
        Path target = artifactRoot.resolve(artifactName).normalize();
        if (!target.startsWith(artifactRoot)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "制品路径越界", "api.common.badRequest");
        }
        return target;
    }

    private String safeEntry(String path) {
        String normalized = path.replace('\\', '/');
        if (normalized.startsWith("/")
                || normalized.contains("../")
                || normalized.equals("..")
                || normalized.contains("\n")
                || normalized.contains("\r")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "生成文件路径越界", "api.common.badRequest");
        }
        return normalized;
    }
}
