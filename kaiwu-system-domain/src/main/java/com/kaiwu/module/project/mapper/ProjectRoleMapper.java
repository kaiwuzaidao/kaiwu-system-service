package com.kaiwu.module.project.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.project.entity.ProjectRoleRow;
import org.apache.ibatis.annotations.Mapper;

/** 项目角色 Mapper；目前只用于批量归属校验，其余读写仍在 {@link ProjectMapper}。 */
@Mapper
public interface ProjectRoleMapper extends BaseMapper<ProjectRoleRow> {}
