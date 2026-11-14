package com.kaiwu.module.operation.service;

import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.operation.dto.request.SchedulerClaimRequest;
import com.kaiwu.module.operation.dto.request.SchedulerCompletionRequest;
import com.kaiwu.module.operation.dto.request.SchedulerJobSaveRequest;
import com.kaiwu.module.operation.dto.request.SchedulerLeaseRequest;
import com.kaiwu.module.operation.dto.request.SchedulerSyncRequest;
import com.kaiwu.module.operation.vo.SchedulerClaimView;
import com.kaiwu.module.operation.vo.SchedulerCredentialView;
import com.kaiwu.module.operation.vo.SchedulerExecutionView;
import com.kaiwu.module.operation.vo.SchedulerHandlerView;
import com.kaiwu.module.operation.vo.SchedulerJobView;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface ProjectSchedulerService {

    PageResult<SchedulerJobView> jobs(String projectId, long current, long size, KaiwuContext actor);

    SchedulerJobView saveJob(String id, SchedulerJobSaveRequest request, KaiwuContext actor, RequestMetadata metadata);

    void deleteJob(String id, KaiwuContext actor, RequestMetadata metadata);

    List<SchedulerHandlerView> handlers(String projectId, KaiwuContext actor);

    /** 项目是否有在线实例注册了该任务类型的 Handler；新建任务与启用任务都要求它为真。 */
    boolean handlerActive(String projectId, String taskType);

    PageResult<SchedulerExecutionView> executions(
            String projectId, String jobId, long current, long size, KaiwuContext actor);

    SchedulerCredentialView rotateCredential(String projectId, KaiwuContext actor, RequestMetadata metadata);

    List<SchedulerJobView> synchronize(String token, SchedulerSyncRequest request);

    SchedulerClaimView claim(String token, SchedulerClaimRequest request);

    void complete(String token, String executionId, SchedulerCompletionRequest request);

    boolean renew(String token, String executionId, SchedulerLeaseRequest request);
}
