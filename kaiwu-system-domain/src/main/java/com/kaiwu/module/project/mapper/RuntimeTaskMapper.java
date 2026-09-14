package com.kaiwu.module.project.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.project.entity.RuntimeTaskEntity;
import org.apache.ibatis.annotations.Mapper;

/** 一次性运行期任务 Mapper；按 taskKey 批量查询与流转都走条件构造器。 */
@Mapper
public interface RuntimeTaskMapper extends BaseMapper<RuntimeTaskEntity> {}
