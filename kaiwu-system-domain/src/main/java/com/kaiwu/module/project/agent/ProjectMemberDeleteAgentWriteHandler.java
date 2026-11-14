package com.kaiwu.module.project.agent;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.service.ProjectService.ProjectMemberExpectation;
import com.kaiwu.port.agent.AgentCapabilityCodes;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Removes a non-founder project member after a frozen preview and strong confirmation. */
@Component
public final class ProjectMemberDeleteAgentWriteHandler implements LocalAgentWriteHandler {
    private static final Set<String> PREVIEW_FIELDS =
            Set.of("projectId", "targetUserId", "username", "status", "roleIds");
    private final ProjectService service;

    public ProjectMemberDeleteAgentWriteHandler(ProjectService service) {
        this.service = service;
    }

    @Override
    public String capabilityCode() {
        return AgentCapabilityCodes.PROJECT_MEMBER_DELETE;
    }

    @Override
    public Map<String, Object> normalize(Map<String, Object> parameters) {
        if (!Set.of("projectId", "targetUserId").containsAll(parameters.keySet()))
            throw new IllegalArgumentException("项目成员参数不合法");
        return Map.of(
                "projectId", ProjectMemberSaveAgentWriteHandler.id(parameters.get("projectId")),
                "targetUserId", ProjectMemberSaveAgentWriteHandler.id(parameters.get("targetUserId")));
    }

    @Override
    public Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor) {
        String projectId = (String) parameters.get("projectId");
        String userId = (String) parameters.get("targetUserId");
        var member = service.previewMemberDeletion(projectId, userId, actor);
        return Map.of(
                "projectId", projectId,
                "targetUserId", userId,
                "username", member.username(),
                "status", member.status(),
                "roleIds", ProjectMemberSaveAgentWriteHandler.joined(member.roleIds()));
    }

    @Override
    public ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.STRONG;
    }

    @Override
    public String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return "移除项目成员 " + previewFields.get("targetUserId") + " " + previewFields.get("username");
    }

    @Override
    public LocalAgentWriteResult executeForAction(
            Map<String, Object> parameters,
            Map<String, String> previewFields,
            KaiwuContext actor,
            RequestMetadata metadata) {
        Map<String, Object> normalized;
        try {
            normalized = normalize(parameters);
        } catch (IllegalArgumentException invalid) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "操作参数不合法", "api.agent.actionParameters");
        }
        if (previewFields == null
                || !previewFields.keySet().equals(PREVIEW_FIELDS)
                || !Objects.equals(normalized.get("projectId"), previewFields.get("projectId"))
                || !Objects.equals(normalized.get("targetUserId"), previewFields.get("targetUserId")))
            throw new ApiException(HttpStatus.BAD_REQUEST, "预览信息无效", "api.agent.actionParameters");
        String userId = (String) normalized.get("targetUserId");
        service.deleteMemberForAgent(
                (String) normalized.get("projectId"),
                userId,
                new ProjectMemberExpectation(
                        true,
                        previewFields.get("username"),
                        previewFields.get("status"),
                        ProjectMemberSaveAgentWriteHandler.parsed(previewFields.get("roleIds"))),
                actor,
                metadata);
        return new LocalAgentWriteResult(userId, null);
    }
}
