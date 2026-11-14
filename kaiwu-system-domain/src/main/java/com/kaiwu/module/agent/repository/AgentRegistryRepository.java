package com.kaiwu.module.agent.repository;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.kaiwu.module.agent.entity.*;
import com.kaiwu.module.agent.mapper.*;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Repository;

/** 仅在 RegistryService 事务中写入；项目行锁保护唯一键检查和状态迁移。 */
@Repository
public class AgentRegistryRepository {
    private final AgentCapabilityMapper capabilities;
    private final AgentCredentialMapper credentials;
    private final AgentRegistryEventMapper events;

    public AgentRegistryRepository(
            AgentCapabilityMapper capabilities, AgentCredentialMapper credentials, AgentRegistryEventMapper events) {
        this.capabilities = capabilities;
        this.credentials = credentials;
        this.events = events;
    }

    public List<AgentCapabilityEntity> visibleCandidates(String userId, LocalDateTime after) {
        return capabilities.visibleCandidates(userId, after);
    }

    public AgentCapabilityEntity byCode(String code) {
        return capabilities.selectOne(
                new LambdaQueryWrapper<AgentCapabilityEntity>().eq(AgentCapabilityEntity::getCapabilityCode, code));
    }

    public String lockProject(String projectId) {
        return capabilities.lockProject(projectId);
    }

    public boolean active(String projectId) {
        return capabilities.countActiveProject(projectId) > 0;
    }

    public boolean isAdmin(String projectId, String userId) {
        return capabilities.countProjectAdmin(projectId, userId) > 0;
    }

    public Set<String> permissions(String projectId) {
        return capabilities.permissions(projectId);
    }

    /** 项目已启用的受控数据资源码，用于校验能力声明的数据范围（ADR 0044）。 */
    public Set<String> controlledResources(String projectId) {
        return capabilities.controlledResources(projectId);
    }

    public AgentCredentialEntity credential(String projectId) {
        return credentials.selectById(projectId);
    }

    public void insertCredential(AgentCredentialEntity row) {
        credentials.insert(row);
    }

    public void updateCredential(AgentCredentialEntity row) {
        credentials.updateById(row);
    }

    public AgentCapabilityEntity capability(String projectId, String code) {
        return capabilities.selectOne(new LambdaQueryWrapper<AgentCapabilityEntity>()
                .eq(AgentCapabilityEntity::getProjectId, projectId)
                .eq(AgentCapabilityEntity::getCapabilityCode, code));
    }

    public long count(String projectId) {
        return capabilities.selectCount(
                new LambdaQueryWrapper<AgentCapabilityEntity>().eq(AgentCapabilityEntity::getProjectId, projectId));
    }

    public List<AgentCapabilityEntity> list(String projectId) {
        com.kaiwu.common.PageBounds.requireSize(100);
        // Registration enforces 100 per project; SQL also bounds legacy/corrupt data.
        return capabilities.selectList(new LambdaQueryWrapper<AgentCapabilityEntity>()
                .eq(AgentCapabilityEntity::getProjectId, projectId)
                .orderByAsc(AgentCapabilityEntity::getCapabilityCode)
                .last("LIMIT 100"));
    }

    public void insertCapability(AgentCapabilityEntity row) {
        capabilities.insert(row);
    }

    public void updateCapability(AgentCapabilityEntity row) {
        // A review reset must clear the old heartbeat. updateById would omit this null.
        capabilities.update(
                null,
                new LambdaUpdateWrapper<AgentCapabilityEntity>()
                        .eq(AgentCapabilityEntity::getId, row.getId())
                        .eq(AgentCapabilityEntity::getProjectId, row.getProjectId())
                        .set(AgentCapabilityEntity::getVersion, row.getVersion())
                        .set(AgentCapabilityEntity::getManifestJson, row.getManifestJson())
                        .set(AgentCapabilityEntity::getManifestHash, row.getManifestHash())
                        .set(AgentCapabilityEntity::getStatus, row.getStatus())
                        .set(AgentCapabilityEntity::getLastSeenAt, row.getLastSeenAt())
                        .set(AgentCapabilityEntity::getUpdatedAt, row.getUpdatedAt()));
    }

    public void invalidate(String projectId, String status, LocalDateTime now) {
        capabilities.update(
                null,
                new LambdaUpdateWrapper<AgentCapabilityEntity>()
                        .eq(AgentCapabilityEntity::getProjectId, projectId)
                        .ne(AgentCapabilityEntity::getStatus, "REVOKED")
                        .set(AgentCapabilityEntity::getStatus, status)
                        .set(AgentCapabilityEntity::getLastSeenAt, null)
                        .set(AgentCapabilityEntity::getUpdatedAt, now));
    }

    public void event(AgentRegistryEventEntity event) {
        events.insert(event);
    }
}
