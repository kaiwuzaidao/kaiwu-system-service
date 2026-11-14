package com.kaiwu.module.factory.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.factory.dto.ProjectManifestRequest;
import com.kaiwu.module.factory.vo.ProjectHandoverView;
import com.kaiwu.module.factory.vo.ProjectManifestPlanView;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;

/**
 * 业务项目平台资源清单同步（ADR 0036）。
 *
 * <p>只增不删为默认：清单里有、平台上没有的条目新增；两边都有的按清单负责的字段更新；平台上多出的
 * 条目只在计划里列为漂移。参数配置的当前值归平台运营；角色及授权（ADR 0042）需显式勾选才导入，
 * 且只追加；上次移交过而本次移交包已没有的条目列为「源环境已删除」，逐项勾选才删除。</p>
 */
public interface ProjectManifestService {

    /** 计算同步计划，不改变任何数据。 */
    ProjectManifestPlanView plan(String projectId, ProjectManifestRequest request, KaiwuContext actor);

    /** 重新计算计划，哈希与请求一致时在一个事务内执行，返回执行的计划。 */
    ProjectManifestPlanView apply(
            String projectId, ProjectManifestRequest request, KaiwuContext actor, RequestMetadata metadata);

    /** 项目的移交记录，最新在前；调用者必须是该项目的有效项目管理员。 */
    List<ProjectHandoverView> handovers(String projectId, KaiwuContext actor);

    /** 一条移交记录及其条目明细；记录不属于该项目时返回 404。 */
    ProjectHandoverView handover(String projectId, String handoverId, KaiwuContext actor);
}
