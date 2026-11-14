package com.kaiwu.module.factory.service;

import com.kaiwu.module.factory.model.TableMeta;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationCreateRequest;
import java.util.List;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface ProjectBlueprintService {

    ProjectBlueprint create(ProjectView project, ProjectGenerationCreateRequest request);

    public record ProjectBlueprint(
            String generationMode,
            String ddl,
            String aiModel,
            String designSummary,
            List<TableMeta> tables,
            String json) {}
}
