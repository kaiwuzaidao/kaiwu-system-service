package com.kaiwu.module.notification;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageBounds;
import com.kaiwu.common.PageResult;
import com.kaiwu.module.notification.dto.NotificationSendRequest;
import com.kaiwu.module.notification.vo.NotificationSummaryView;
import com.kaiwu.module.notification.vo.NotificationView;
import com.kaiwu.port.UserNotificationPort;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * 站内信：集中存储在 System 库的统一收件箱（ADR 0007）。
 *
 * <p>读取只针对当前登录用户自己，不接受 userId 参数；写入分两条路径：
 * 平台内部事件直接调用 {@link #notifyUser}，业务服务经投递端点调用 {@link #deliver}。
 */
@Service
public class NotificationService implements UserNotificationPort {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    /** 顶栏铃铛下拉最多展示的未读条数。 */
    private static final int RECENT_LIMIT = 5;

    private static final String DEFAULT_TYPE = "SYSTEM";

    private static final AtomicLong ID_SEQUENCE = new AtomicLong(System.currentTimeMillis() * 1_000_000L);

    private final NotificationRepository repository;

    public NotificationService(NotificationRepository repository) {
        this.repository = repository;
    }

    /**
     * 当前用户的站内信分页；只能读自己的，收件人由调用方从会话取得而非请求参数。
     *
     * <p>越界参数直接拒绝，与其它列表接口保持同一语义：静默截断会让调用方以为拿到了全量。</p>
     */
    public PageResult<NotificationView> myNotifications(
            String userId, long current, long size, boolean unreadOnly, String type) {
        PageBounds.require(current, size);
        long page = current;
        long pageSize = size;
        String filterType = StringUtils.hasText(type) ? type.trim() : null;
        long total = repository.count(userId, unreadOnly, filterType);
        List<NotificationView> records =
                repository.page(userId, unreadOnly, filterType, (page - 1) * pageSize, pageSize).stream()
                        .map(NotificationService::toView)
                        .toList();
        return new PageResult<>(page, pageSize, total, records);
    }

    /** 顶栏铃铛：未读数 + 最近若干条未读。 */
    public NotificationSummaryView summary(String userId) {
        return new NotificationSummaryView(
                repository.count(userId, true, null),
                repository.recentUnread(userId, RECENT_LIMIT).stream()
                        .map(NotificationService::toView)
                        .toList());
    }

    /** 标记单条已读；WHERE 同时限定收件人，越权标记他人消息会更新 0 行。 */
    @Transactional
    public void markRead(String id, String userId) {
        // WHERE 已限定收件人；更新 0 行说明消息不存在、已读或不属于当前用户。
        if (repository.markRead(id, userId) == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "消息不存在或已读", "api.common.notFound");
        }
    }

    @Transactional
    public long markAllRead(String userId) {
        return repository.markAllRead(userId);
    }

    /**
     * 平台内部事件产生的站内信，直接写库，不经 HTTP 投递端点。
     *
     * <p>站内信是尽力而为的通知，失败只记录日志，绝不阻断调用方业务。
     */
    @Override
    public void notifyUser(String recipientUserId, String type, String title, String content, String linkUrl) {
        try {
            repository.insert(new NotificationRepository.NotificationRow(
                    nextId(),
                    recipientUserId,
                    null,
                    null,
                    StringUtils.hasText(type) ? type : DEFAULT_TYPE,
                    title,
                    content,
                    linkUrl,
                    null,
                    null));
        } catch (RuntimeException exception) {
            log.warn("站内信写入失败，已忽略：recipient={}, title={}", recipientUserId, title, exception);
        }
    }

    /**
     * 业务服务投递站内信。校验来源项目存在且启用、收件人是该项目有效成员，
     * 防止任一业务服务向平台全体用户群发（ADR 0007 第 5 条）。
     */
    @Transactional
    public void deliver(NotificationSendRequest request) {
        NotificationRepository.ProjectRef project = repository
                .enabledProjectByCode(request.projectCode().trim())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "来源项目不存在或未启用", "api.common.notFound"));
        if (!repository.activeMemberExists(project.id(), request.recipientUserId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "收件人不是该项目的有效成员", "api.common.forbidden");
        }
        repository.insert(new NotificationRepository.NotificationRow(
                nextId(),
                request.recipientUserId(),
                project.id(),
                project.projectCode(),
                StringUtils.hasText(request.notificationType()) ? request.notificationType() : "PROJECT",
                request.title(),
                request.content(),
                request.linkUrl(),
                null,
                null));
    }

    private static NotificationView toView(NotificationRepository.NotificationRow row) {
        return new NotificationView(
                row.id(),
                row.projectId(),
                row.projectCode(),
                row.notificationType(),
                row.title(),
                row.content(),
                row.linkUrl(),
                row.readAt(),
                row.createdAt());
    }

    private static String nextId() {
        return String.valueOf(ID_SEQUENCE.incrementAndGet());
    }
}
