package com.kaiwu.module.factory.service.impl;

import com.kaiwu.common.LongIdGenerator;
import com.kaiwu.module.factory.entity.ProjectHandoverRow;
import com.kaiwu.module.factory.mapper.ProjectHandoverMapper;
import com.kaiwu.module.factory.vo.ProjectHandoverView;
import com.kaiwu.module.factory.vo.ProjectManifestPlanView;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

/**
 * 项目配置移交记录的读写（ADR 0042）。
 *
 * <p>成功记录与业务写入在同一事务里提交，保证「配置已改」与「记录已写」一致；失败记录用独立事务写入，
 * 业务写入回滚后失败原因仍然保留。记录里的业务键清单是下一次导入识别「源环境已删除」的基线，
 * 不保存数据库 ID、密钥与成员。</p>
 */
@Service
public class ProjectHandoverRecorder {

    private static final int LIST_LIMIT = 50;
    private static final int REASON_LIMIT = 500;

    private final ProjectHandoverMapper mapper;
    private final ObjectMapper objectMapper;

    /** 注入记录 Mapper 与 JSON 序列化器。 */
    public ProjectHandoverRecorder(ProjectHandoverMapper mapper, ObjectMapper objectMapper) {
        this.mapper = mapper;
        this.objectMapper = objectMapper;
    }

    /**
     * 最近一次成功移交的业务键，作为删除比对的基线。
     *
     * @param projectId 项目 ID
     * @return 业务键集合；该项目从未成功移交过时为空
     */
    public Optional<Set<String>> baselineKeys(String projectId) {
        String json = mapper.latestSuccessKeysJson(projectId);
        if (json == null || json.isBlank()) {
            return Optional.empty();
        }
        List<String> keys = objectMapper.readValue(json, new TypeReference<List<String>>() {});
        return Optional.of(new LinkedHashSet<>(keys));
    }

    /**
     * 同一移交包摘要最近一次成功的记录。
     *
     * @param projectId 项目 ID
     * @param digest    移交包摘要，为空时直接返回空
     * @return 记录摘要
     */
    public Optional<ProjectHandoverRow> findAppliedByDigest(String projectId, String digest) {
        if (digest == null || digest.isBlank()) {
            return Optional.empty();
        }
        return Optional.ofNullable(mapper.latestSuccessByDigest(projectId, digest));
    }

    /**
     * 写入成功记录，加入调用方的事务。
     *
     * @param row         记录摘要，ID 与创建时间由本方法和数据库生成
     * @param changes     本次计划的全部条目
     * @param packageKeys 移交包内全部条目的业务键
     */
    @Transactional
    public void recordSuccess(
            ProjectHandoverRow row, List<ProjectManifestPlanView.Change> changes, Set<String> packageKeys) {
        mapper.insert(
                withId(row), objectMapper.writeValueAsString(changes), objectMapper.writeValueAsString(packageKeys));
    }

    /**
     * 写入失败记录，使用独立事务，调用方的业务写入回滚后仍然保留。
     *
     * @param row     记录摘要，失败原因会被截断到 500 字符
     * @param changes 本次计划的全部条目
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordFailure(ProjectHandoverRow row, List<ProjectManifestPlanView.Change> changes) {
        mapper.insert(withId(row), objectMapper.writeValueAsString(changes), null);
    }

    /**
     * 项目的移交记录，最新在前。
     *
     * @param projectId 项目 ID
     * @return 记录摘要，不含条目明细
     */
    public List<ProjectHandoverView> list(String projectId) {
        return mapper.list(projectId, LIST_LIMIT).stream()
                .map(row -> view(row, List.of()))
                .toList();
    }

    /**
     * 一条移交记录及其条目明细。
     *
     * @param projectId 项目 ID，限定范围，防止跨项目读取
     * @param id        记录 ID
     * @return 记录；不存在时为空
     */
    public Optional<ProjectHandoverView> detail(String projectId, String id) {
        ProjectHandoverRow row = mapper.find(projectId, id);
        if (row == null) {
            return Optional.empty();
        }
        String json = mapper.changesJson(projectId, id);
        List<ProjectManifestPlanView.Change> changes = json == null || json.isBlank()
                ? List.of()
                : objectMapper.readValue(json, new TypeReference<List<ProjectManifestPlanView.Change>>() {});
        return Optional.of(view(row, changes));
    }

    /** 补全 ID，并截断过长的失败原因。 */
    private static ProjectHandoverRow withId(ProjectHandoverRow row) {
        String reason = row.failureReason();
        if (reason != null && reason.length() > REASON_LIMIT) {
            reason = reason.substring(0, REASON_LIMIT);
        }
        return new ProjectHandoverRow(
                LongIdGenerator.nextId(),
                row.projectId(),
                row.status(),
                row.packageDigest(),
                row.sourceHost(),
                row.sourceExportedBy(),
                row.sourceExportedAt(),
                row.planHash(),
                row.gitCommit(),
                row.appliedAccess(),
                row.changeCount(),
                row.deleteCount(),
                reason,
                row.operatorId(),
                row.createdAt());
    }

    /** 转成对外视图。 */
    private static ProjectHandoverView view(ProjectHandoverRow row, List<ProjectManifestPlanView.Change> changes) {
        return new ProjectHandoverView(
                row.id(),
                row.status(),
                row.packageDigest(),
                row.sourceHost(),
                row.sourceExportedBy(),
                row.sourceExportedAt(),
                row.operatorId(),
                row.appliedAccess(),
                row.changeCount(),
                row.deleteCount(),
                row.failureReason(),
                row.createdAt(),
                changes);
    }
}
