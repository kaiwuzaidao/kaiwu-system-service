package com.kaiwu.module.auth.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.auth.entity.OnlineSessionEntity;
import org.apache.ibatis.annotations.Mapper;

/**
 * 在线会话 Mapper，跨模块共用。
 *
 * <p>按用户批量查询与撤销会话走条件构造器的 {@code in()}，不需要任何自定义 SQL。</p>
 */
@Mapper
public interface OnlineSessionMapper extends BaseMapper<OnlineSessionEntity> {}
