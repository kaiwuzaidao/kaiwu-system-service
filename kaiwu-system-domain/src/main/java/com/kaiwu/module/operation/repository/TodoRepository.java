package com.kaiwu.module.operation.repository;

import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.kaiwu.common.PageBounds;
import com.kaiwu.module.operation.entity.TodoEntity;
import com.kaiwu.module.operation.mapper.TodoMapper;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Repository;
import org.springframework.util.StringUtils;

/**
 * 统一待办读写（ADR 0034）。
 *
 * <p>状态由来源服务维护：这里只提供「打开」与「关闭」两个幂等写入，以及收件人自己的只读查询，
 * 不提供收件人改状态的路径。
 */
@Repository
public class TodoRepository {

    private final TodoMapper mapper;
    private final Clock clock;

    /**
     * 创建仓储。
     *
     * @param mapper 待办 Mapper
     */
    public TodoRepository(TodoMapper mapper) {
        this(mapper, Clock.systemUTC());
    }

    /** 与平台使用相同配置时钟，旧列保留本地时间，受管UTC列只在读取时换算。 */
    @Autowired
    public TodoRepository(TodoMapper mapper, Clock clock) {
        this.mapper = mapper;
        this.clock = clock;
    }

    /**
     * 打开待办：新建或更新内容并重新打开。
     *
     * @param row 待办内容
     */
    public void upsertOpen(TodoRow row) {
        TodoEntity entity = new TodoEntity();
        entity.setId(Long.parseLong(row.id()));
        entity.setProjectId(Long.parseLong(row.projectId()));
        entity.setProjectCode(row.projectCode());
        entity.setBizKey(row.bizKey());
        entity.setRecipientUserId(Long.parseLong(row.recipientUserId()));
        entity.setTitle(row.title());
        entity.setContent(row.content());
        entity.setLinkUrl(row.linkUrl());
        entity.setDueAt(row.dueAt());
        entity.setOpenedAt(row.openedAt());
        entity.setCreatedAt(row.createdAt());
        entity.setUpdatedAt(row.updatedAt());
        mapper.upsertOpen(entity);
    }

    /**
     * 关闭待办。只会改动仍是 OPEN 的行，因此对已关闭或不存在的目标重复调用不会有任何副作用。
     *
     * @param projectCode 来源项目编码
     * @param bizKey 业务唯一键
     * @param recipientUserId 只关闭该处理人的待办；为空则关闭该业务键下所有处理人的
     * @param status 目标状态：DONE 或 CANCELLED
     * @param now 写入关闭时间的当前时间
     * @return 实际关闭的行数
     */
    public int close(String projectCode, String bizKey, String recipientUserId, String status, LocalDateTime now) {
        LambdaUpdateWrapper<TodoEntity> update = new LambdaUpdateWrapper<TodoEntity>()
                .eq(TodoEntity::getProjectCode, projectCode)
                .eq(TodoEntity::getBizKey, bizKey)
                .eq(TodoEntity::getStatus, "OPEN")
                .set(TodoEntity::getStatus, status)
                .set(TodoEntity::getClosedAt, now)
                .set(TodoEntity::getUpdatedAt, now);
        if (StringUtils.hasText(recipientUserId)) {
            update.eq(TodoEntity::getRecipientUserId, Long.parseLong(recipientUserId));
        }
        return mapper.update(null, update);
    }

    /**
     * 某收件人的待办分页；筛选条件与 {@link #count} 共用，保证总数与列表一致。
     *
     * @param recipientUserId 收件人
     * @param status 状态筛选
     * @param projectCode 来源项目筛选，可空
     * @param offset 偏移量
     * @param size 页大小
     * @return 当前页待办，按打开时间倒序
     */
    public List<TodoRow> page(String recipientUserId, String status, String projectCode, long offset, long size) {
        // 出口处兜底：这里是真正拼 LIMIT 的地方，Service 是否校验过不影响本行的责任。
        PageBounds.requireSize(size);
        return mapper
                .pageVisible(
                        Long.parseLong(recipientUserId),
                        status,
                        StringUtils.hasText(projectCode) ? projectCode : null,
                        offset,
                        size)
                .stream()
                .map(this::toRow)
                .toList();
    }

    /**
     * 某收件人满足筛选条件的待办总数。
     *
     * @param recipientUserId 收件人
     * @param status 状态筛选
     * @param projectCode 来源项目筛选，可空
     * @return 总数
     */
    public long count(String recipientUserId, String status, String projectCode) {
        return mapper.countVisible(
                Long.parseLong(recipientUserId), status, StringUtils.hasText(projectCode) ? projectCode : null);
    }

    /**
     * 最近打开的若干条未处理待办，供工作台概览使用。
     *
     * @param recipientUserId 收件人
     * @param limit 条数
     * @return 待办列表，按打开时间倒序
     */
    public List<TodoRow> recentOpen(String recipientUserId, int limit) {
        PageBounds.requireSize(limit);
        return mapper.pageVisible(Long.parseLong(recipientUserId), "OPEN", null, 0, limit).stream()
                .map(this::toRow)
                .toList();
    }

    /**
     * 统计某收件人已逾期的未处理待办。
     *
     * @param recipientUserId 收件人
     * @param now 判定逾期的当前时间
     * @return 已逾期数量
     */
    public long countOverdue(String recipientUserId, LocalDateTime now) {
        return mapper.countVisibleOverdue(
                Long.parseLong(recipientUserId),
                now,
                now.atZone(clock.getZone()).withZoneSameInstant(ZoneOffset.UTC).toLocalDateTime());
    }

    /**
     * 某收件人在某项目下处于 OPEN 的待办数。
     *
     * @param projectCode 来源项目编码
     * @param recipientUserId 收件人
     * @return OPEN 待办数
     */
    public long countOpenByRecipient(String projectCode, String recipientUserId) {
        return mapper.countOpenByRecipient(projectCode, Long.parseLong(recipientUserId));
    }

    /**
     * 某条待办当前是否已经是 OPEN。
     *
     * @param projectCode 来源项目编码
     * @param bizKey 业务唯一键
     * @param recipientUserId 收件人
     * @return 已是 OPEN 为 true
     */
    public boolean isOpen(String projectCode, String bizKey, String recipientUserId) {
        return mapper.countOpenByKey(projectCode, bizKey, Long.parseLong(recipientUserId)) > 0;
    }

    /**
     * 分批兜底取消长期未处理的待办。
     *
     * @param before 截止线
     * @param now 当前时间
     * @param batchSize 单批行数
     * @return 本批取消行数
     */
    public int cancelStaleBefore(LocalDateTime before, LocalDateTime now, int batchSize) {
        return mapper.cancelStaleBefore(before, now, batchSize);
    }

    /**
     * 分批物理删除关闭已久的待办。
     *
     * @param before 截止线
     * @param batchSize 单批行数
     * @return 本批删除行数
     */
    public int deleteClosedBefore(LocalDateTime before, int batchSize) {
        return mapper.deleteClosedBefore(before, batchSize);
    }

    /**
     * 按项目编码查启用中的项目，用于校验投递来源。
     *
     * @param projectCode 项目编码
     * @return 项目引用，不存在或未启用为空
     */
    public Optional<ProjectRef> enabledProjectByCode(String projectCode) {
        Map<String, Object> row = mapper.findEnabledProjectByCode(projectCode);
        return row == null || row.isEmpty()
                ? Optional.empty()
                : Optional.of(new ProjectRef(String.valueOf(row.get("id")), String.valueOf(row.get("projectCode"))));
    }

    /**
     * 收件人必须是该项目的有效成员。
     *
     * @param projectId 项目 ID
     * @param userId 用户 ID
     * @return 是有效成员为 true
     */
    public boolean activeMemberExists(String projectId, String userId) {
        return mapper.countActiveMember(Long.parseLong(projectId), Long.parseLong(userId)) > 0;
    }

    /** 实体转仓储行；ID 一律以字符串对外，避免 19 位数字在 JSON 里丢精度。 */
    private TodoRow toRow(TodoEntity entity) {
        return new TodoRow(
                String.valueOf(entity.getId()),
                String.valueOf(entity.getProjectId()),
                entity.getProjectCode(),
                entity.getBizKey(),
                String.valueOf(entity.getRecipientUserId()),
                entity.getTitle(),
                entity.getContent(),
                entity.getLinkUrl(),
                entity.getStatus(),
                displayTime(entity, entity.getDueAt()),
                displayTime(entity, entity.getOpenedAt()),
                displayTime(entity, entity.getClosedAt()),
                displayTime(entity, entity.getCreatedAt()),
                displayTime(entity, entity.getUpdatedAt()));
    }

    /** 受管UTC列按配置时区显示，旧待办和dueAt代表的时刻均不被改写。 */
    private LocalDateTime displayTime(TodoEntity entity, LocalDateTime value) {
        return value == null || !entity.isManagedProjection()
                ? value
                : value.atOffset(ZoneOffset.UTC)
                        .atZoneSameInstant(clock.getZone())
                        .toLocalDateTime();
    }

    /**
     * 待办行。
     *
     * @param id 待办 ID
     * @param projectId 来源项目 ID
     * @param projectCode 来源项目编码
     * @param bizKey 业务唯一键
     * @param recipientUserId 处理人
     * @param title 标题
     * @param content 正文
     * @param linkUrl 跳转路径
     * @param status 状态
     * @param dueAt 截止时间
     * @param openedAt 打开时间
     * @param closedAt 关闭时间
     * @param createdAt 创建时间
     * @param updatedAt 最后更新时间
     */
    public record TodoRow(
            String id,
            String projectId,
            String projectCode,
            String bizKey,
            String recipientUserId,
            String title,
            String content,
            String linkUrl,
            String status,
            LocalDateTime dueAt,
            LocalDateTime openedAt,
            LocalDateTime closedAt,
            LocalDateTime createdAt,
            LocalDateTime updatedAt) {}

    /**
     * 项目引用。
     *
     * @param id 项目 ID
     * @param projectCode 项目编码
     */
    public record ProjectRef(String id, String projectCode) {}
}
