package com.kaiwu.module.project.mapper;

import com.kaiwu.module.project.entity.BackendServiceRow;
import java.util.List;
import org.apache.ibatis.annotations.*;

/** 后端服务登记表的单项目数据库操作。 */
@Mapper
public interface ProjectBackendServiceMapper {
    /** 查询当前项目服务登记，锁粒度由事务控制。 */
    @Select(
            "SELECT service_code,service_url,status FROM sys_project_backend_service WHERE project_id=#{projectId} ORDER BY service_code")
    List<BackendServiceRow> list(@Param("projectId") String projectId);

    /** 查询单条服务的存在性和当前状态。 */
    @Select(
            "SELECT service_code,service_url,status FROM sys_project_backend_service WHERE project_id=#{projectId} AND service_code=#{serviceCode}")
    BackendServiceRow find(@Param("projectId") String projectId, @Param("serviceCode") String serviceCode);

    /** 新增非 default 服务，唯一键处理并发冲突。 */
    @Insert(
            "INSERT INTO sys_project_backend_service(project_id,service_code,service_url,status,created_at,updated_at) VALUES(#{projectId},#{serviceCode},#{url},'ENABLED',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)")
    int insert(
            @Param("projectId") String projectId, @Param("serviceCode") String serviceCode, @Param("url") String url);

    /** 更新服务地址。 */
    @Update(
            "UPDATE sys_project_backend_service SET service_url=#{url},updated_at=CURRENT_TIMESTAMP WHERE project_id=#{projectId} AND service_code=#{serviceCode}")
    int updateUrl(
            @Param("projectId") String projectId, @Param("serviceCode") String serviceCode, @Param("url") String url);

    /** 同一项目内启用或停用服务。 */
    @Update(
            "UPDATE sys_project_backend_service SET status=#{status},updated_at=CURRENT_TIMESTAMP WHERE project_id=#{projectId} AND service_code=#{serviceCode}")
    int updateStatus(
            @Param("projectId") String projectId,
            @Param("serviceCode") String serviceCode,
            @Param("status") String status);

    /** 更新旧项目字段，供 default 地址保持唯一语义。 */
    @Update("UPDATE sys_project SET service_url=#{url},updated_at=CURRENT_TIMESTAMP WHERE id=#{projectId}")
    int updateLegacyUrl(@Param("projectId") String projectId, @Param("url") String url);
}
