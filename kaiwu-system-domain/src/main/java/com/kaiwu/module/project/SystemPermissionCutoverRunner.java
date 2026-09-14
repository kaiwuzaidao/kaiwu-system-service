package com.kaiwu.module.project;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.kaiwu.module.project.entity.RuntimeTaskEntity;
import com.kaiwu.module.project.mapper.RuntimeTaskMapper;
import com.kaiwu.port.SessionSnapshotPort;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

/**
 * 清理权限 migration 前签发的 Redis 会话快照。
 */
@Component
@Order(30)
public class SystemPermissionCutoverRunner implements ApplicationRunner {

    static final String LEGACY_TASK_KEY = "system-project-session-cutover";
    static final String AI_PROVIDER_TASK_KEY = "system-ai-provider-permission-cutover";
    static final String PROJECT_FACTORY_TASK_KEY = "system-project-factory-permission-cutover";

    private final RuntimeTaskMapper taskMapper;
    private final SessionSnapshotPort sessionSnapshots;
    private final Clock clock;

    public SystemPermissionCutoverRunner(
            RuntimeTaskMapper taskMapper, SessionSnapshotPort sessionSnapshots, Clock clock) {
        this.taskMapper = taskMapper;
        this.sessionSnapshots = sessionSnapshots;
        this.clock = clock;
    }

    @Override
    public void run(ApplicationArguments args) {
        List<String> taskKeys = List.of(LEGACY_TASK_KEY, AI_PROVIDER_TASK_KEY, PROJECT_FACTORY_TASK_KEY);
        Long pending = taskMapper.selectCount(pendingTasks(taskKeys));
        if (pending == null || pending == 0) return;

        sessionSnapshots.deleteAll();
        taskMapper.update(
                null,
                new LambdaUpdateWrapper<RuntimeTaskEntity>()
                        .eq(RuntimeTaskEntity::getTaskStatus, "PENDING")
                        .in(RuntimeTaskEntity::getTaskKey, taskKeys)
                        .set(RuntimeTaskEntity::getTaskStatus, "DONE")
                        .set(RuntimeTaskEntity::getCompletedAt, LocalDateTime.now(clock)));
    }

    /** 待执行的切换任务；查询与流转共用同一组条件，避免两处漂移。 */
    private static LambdaQueryWrapper<RuntimeTaskEntity> pendingTasks(List<String> taskKeys) {
        return new LambdaQueryWrapper<RuntimeTaskEntity>()
                .eq(RuntimeTaskEntity::getTaskStatus, "PENDING")
                .in(RuntimeTaskEntity::getTaskKey, taskKeys);
    }
}
