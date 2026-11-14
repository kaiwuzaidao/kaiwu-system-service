package com.kaiwu.module.factory.service;

import java.util.Map;
import org.springframework.core.io.Resource;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface CodegenArtifactService {

    String create(String taskNo, Map<String, String> files);

    String createProjectArtifact(String taskNo, String repositoryType, String projectCode, Map<String, String> files);

    Resource resource(String artifactName);

    Map<String, String> readFiles(String artifactName);

    void deleteQuietly(String artifactName);
}
