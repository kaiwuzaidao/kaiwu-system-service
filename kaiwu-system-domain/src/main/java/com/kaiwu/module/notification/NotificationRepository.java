package com.kaiwu.module.notification;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.kaiwu.common.PageBounds;
import com.kaiwu.module.notification.entity.NotificationEntity;
import com.kaiwu.module.notification.mapper.NotificationMapper;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.stereotype.Repository;
import org.springframework.util.StringUtils;

/**
 * 站内信读写；消息是不可变事实，只允许新增和收件人翻转自己的 read_at（ADR 0007）。
 */
@Repository
public class NotificationRepository {

    private final NotificationMapper mapper;

    private final Clock clock;

    public NotificationRepository(NotificationMapper mapper, Clock clock) {
        this.mapper = mapper;
        this.clock = clock;
    }

    /** 某收件人的站内信分页；筛选条件与 {@code count} 共用，保证未读数与列表一致。 */
    public List<NotificationRow> page(String recipientUserId, boolean unreadOnly, String type, long offset, long size) {
        // 出口处兜底：这里是真正拼 LIMIT 的地方，Service 是否校验过不影响本行的责任。
        PageBounds.requireSize(size);
        LambdaQueryWrapper<NotificationEntity> query = filter(recipientUserId, unreadOnly, type)
                .orderByDesc(NotificationEntity::getCreatedAt)
                .orderByDesc(NotificationEntity::getId)
                // 调用方按 offset/size 分页，不走 MP 的 Page 对象；两者混用会重复加 LIMIT。
                .last("LIMIT " + size + " OFFSET " + offset);
        return mapper.selectList(query).stream()
                .map(NotificationRepository::toRow)
                .toList();
    }

    public long count(String recipientUserId, boolean unreadOnly, String type) {
        return mapper.selectCount(filter(recipientUserId, unreadOnly, type));
    }

    /** 最近若干条未读，供顶栏铃铛下拉展示。 */
    public List<NotificationRow> recentUnread(String recipientUserId, int limit) {
        return mapper
                .selectList(filter(recipientUserId, true, null)
                        .orderByDesc(NotificationEntity::getCreatedAt)
                        .orderByDesc(NotificationEntity::getId)
                        .last("LIMIT " + limit))
                .stream()
                .map(NotificationRepository::toRow)
                .toList();
    }

    /** 写入一条站内信；消息是不可变事实，新消息一律未读（ADR 0007）。 */
    public void insert(NotificationRow row) {
        NotificationEntity entity = new NotificationEntity();
        entity.setId(Long.parseLong(row.id()));
        entity.setRecipientUserId(Long.parseLong(row.recipientUserId()));
        entity.setProjectId(StringUtils.hasText(row.projectId()) ? Long.parseLong(row.projectId()) : null);
        entity.setProjectCode(row.projectCode());
        entity.setNotificationType(row.notificationType());
        entity.setTitle(row.title());
        entity.setContent(row.content());
        entity.setLinkUrl(row.linkUrl());
        // 新消息一律未读；read_at 只由收件人自己翻转。
        entity.setReadAt(null);
        entity.setCreatedAt(LocalDateTime.now(clock));
        mapper.insert(entity);
    }

    /**
     * 标记单条已读；WHERE 同时限定收件人，避免越权标记他人消息。
     *
     * @return 实际更新行数，0 表示消息不存在或不属于该用户
     */
    public int markRead(String id, String recipientUserId) {
        return mapper.markRead(Long.parseLong(id), Long.parseLong(recipientUserId));
    }

    public int markAllRead(String recipientUserId) {
        return mapper.markAllRead(Long.parseLong(recipientUserId));
    }

    /** 按项目编码查启用中的项目，用于校验投递来源。 */
    public Optional<ProjectRef> enabledProjectByCode(String projectCode) {
        Map<String, Object> row = mapper.findEnabledProjectByCode(projectCode);
        return row == null || row.isEmpty()
                ? Optional.empty()
                : Optional.of(new ProjectRef(String.valueOf(row.get("id")), String.valueOf(row.get("projectCode"))));
    }

    /** 收件人必须是该项目的有效成员，防止业务服务向全体用户群发。 */
    public boolean activeMemberExists(String projectId, String userId) {
        return mapper.countActiveMember(Long.parseLong(projectId), Long.parseLong(userId)) > 0;
    }

    /** 列表与计数共用的筛选条件，保证「未读数」与「未读列表」永远一致。 */
    private static LambdaQueryWrapper<NotificationEntity> filter(
            String recipientUserId, boolean unreadOnly, String type) {
        LambdaQueryWrapper<NotificationEntity> query = new LambdaQueryWrapper<NotificationEntity>()
                .eq(NotificationEntity::getRecipientUserId, Long.parseLong(recipientUserId));
        if (unreadOnly) {
            query.isNull(NotificationEntity::getReadAt);
        }
        if (StringUtils.hasText(type)) {
            query.eq(NotificationEntity::getNotificationType, type);
        }
        return query;
    }

    private static NotificationRow toRow(NotificationEntity entity) {
        return new NotificationRow(
                String.valueOf(entity.getId()),
                String.valueOf(entity.getRecipientUserId()),
                entity.getProjectId() == null ? null : String.valueOf(entity.getProjectId()),
                entity.getProjectCode(),
                entity.getNotificationType(),
                entity.getTitle(),
                entity.getContent(),
                entity.getLinkUrl(),
                entity.getReadAt(),
                entity.getCreatedAt());
    }

    public record NotificationRow(
            String id,
            String recipientUserId,
            String projectId,
            String projectCode,
            String notificationType,
            String title,
            String content,
            String linkUrl,
            LocalDateTime readAt,
            LocalDateTime createdAt) {}

    public record ProjectRef(String id, String projectCode) {}
}
