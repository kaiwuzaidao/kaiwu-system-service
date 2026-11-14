package com.kaiwu.module.factory.service;

import com.kaiwu.module.projectgeneration.dto.ProjectGenerationCreateRequest;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationRetryRequest;
import com.kaiwu.module.projectgeneration.vo.ProjectGenerationInputView;
import com.kaiwu.module.projectgeneration.vo.ProjectGenerationView;
import java.util.List;
import org.springframework.core.io.Resource;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface ProjectGenerationService {

    ProjectGenerationView create(ProjectGenerationCreateRequest request, String ownerUserId);

    List<ProjectGenerationView> list(String ownerUserId, String projectId);

    ProjectGenerationView get(String taskNo, String ownerUserId);

    ProjectGenerationInputView editableInput(String taskNo, String ownerUserId);

    ProjectGenerationView retry(String taskNo, ProjectGenerationRetryRequest request, String ownerUserId);

    Download download(String taskNo, String repositoryType, String ownerUserId);

    void enqueue(String taskNo);

    public record Download(String filename, Resource resource) {}
}
