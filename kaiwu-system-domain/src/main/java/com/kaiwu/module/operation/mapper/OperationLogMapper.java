package com.kaiwu.module.operation.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.operation.entity.OperationLogEntity;
import org.apache.ibatis.annotations.Mapper;

/** 操作审计日志 Mapper。 */
@Mapper
public interface OperationLogMapper extends BaseMapper<OperationLogEntity> {}
