package com.kaiwu.module.connector.repository;

import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.kaiwu.module.connector.entity.AiModelRouteEntity;
import com.kaiwu.module.connector.mapper.AiModelRouteMapper;
import org.springframework.stereotype.Repository;

/** 模型用途绑定持久化；一次更新两个用途避免部分生效。 */
@Repository
public class AiModelRouteRepository {
    private final AiModelRouteMapper mapper;

    public AiModelRouteRepository(AiModelRouteMapper mapper) {
        this.mapper = mapper;
    }

    public AiModelRouteEntity current() {
        return mapper.selectById(1L);
    }

    public void save(Long plan, Long answer) {
        int updated = mapper.update(
                null,
                new LambdaUpdateWrapper<AiModelRouteEntity>()
                        .eq(AiModelRouteEntity::getId, 1L)
                        .set(AiModelRouteEntity::getPlanModelId, plan)
                        .set(AiModelRouteEntity::getAnswerModelId, answer));
        if (updated != 1) throw new IllegalStateException("模型路由配置不存在，请检查数据库迁移");
    }
}
