package com.kaiwu.module.audit.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.audit.entity.OperationLogEntity;
import org.apache.ibatis.annotations.Mapper;

/** 操作审计日志 Mapper。 */
@Mapper
public interface OperationLogMapper extends BaseMapper<OperationLogEntity> {}
