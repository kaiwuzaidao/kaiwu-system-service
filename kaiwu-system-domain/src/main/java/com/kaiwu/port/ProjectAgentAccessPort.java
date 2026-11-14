package com.kaiwu.port;

import com.kaiwu.module.project.vo.ProjectAccessView;
import java.util.Optional;

/** Agent 每次执行均从项目事实源重新取得权限，不使用 Gateway 的入口缓存。 */
public interface ProjectAgentAccessPort {
    Optional<ProjectAccessView> resolve(String projectCode, String userId);
}
