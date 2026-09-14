package com.kaiwu.module.audit.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.audit.entity.LoginLogEntity;
import org.apache.ibatis.annotations.Mapper;

/** 登录日志 Mapper。 */
@Mapper
public interface LoginLogMapper extends BaseMapper<LoginLogEntity> {}
