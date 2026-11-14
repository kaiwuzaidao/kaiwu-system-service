package com.kaiwu.module.agent.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

/** 批量批准只读能力；每项都绑定审核者看到的确切版本与清单摘要。 */
public record AgentCapabilityBatchReviewRequest(
        @NotNull @Size(min = 1, max = 50) List<@NotNull @Valid AgentCapabilityRevision> revisions) {}
