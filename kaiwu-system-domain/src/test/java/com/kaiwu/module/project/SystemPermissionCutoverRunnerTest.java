package com.kaiwu.module.project;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import com.kaiwu.module.project.entity.RuntimeTaskEntity;
import com.kaiwu.module.project.mapper.RuntimeTaskMapper;
import com.kaiwu.port.SessionSnapshotPort;
import java.time.Clock;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

class SystemPermissionCutoverRunnerTest {

    /**
     * 条件构造器依赖 MyBatis-Plus 的实体元数据（列名缓存），而这份缓存平时由 Spring 启动时
     * 扫描 Mapper 建立。纯单元测试里 Mapper 是 Mockito 假对象，缓存不会被建立，
     * {@code LambdaQueryWrapper} 会抛「can not find lambda cache for this entity」。
     * 这里显式初始化被测代码用到的实体。
     */
    @BeforeAll
    static void initEntityMetadata() {
        TableInfoHelper.initTableInfo(
                new MapperBuilderAssistant(new MybatisConfiguration(), ""), RuntimeTaskEntity.class);
    }

    @Test
    void pendingCutoverDeletesRedisSessionsAndMarksTaskDone() throws Exception {
        RuntimeTaskMapper taskMapper = mock(RuntimeTaskMapper.class);
        SessionSnapshotPort sessionSnapshots = mock(SessionSnapshotPort.class);
        // 有待执行的切换任务，才会清快照并把任务置为 DONE。
        when(taskMapper.selectCount(any())).thenReturn(1L);

        new SystemPermissionCutoverRunner(taskMapper, sessionSnapshots, Clock.systemDefaultZone()).run(null);

        verify(sessionSnapshots).deleteAll();
        // 流转用 update(null, wrapper)：实体传 null，全部字段由 wrapper 的 set() 指定，
        // 避免 MyBatis-Plus 跳过 null 字段导致 completed_at 写不进去。
        verify(taskMapper).update(isNull(), any());
    }
}
