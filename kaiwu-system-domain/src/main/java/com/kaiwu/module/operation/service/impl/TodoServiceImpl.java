package com.kaiwu.module.operation.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageBounds;
import com.kaiwu.common.PageResult;
import com.kaiwu.module.operation.config.TodoProperties;
import com.kaiwu.module.operation.dto.TodoCloseRequest;
import com.kaiwu.module.operation.dto.TodoOpenRequest;
import com.kaiwu.module.operation.repository.TodoRepository;
import com.kaiwu.module.operation.service.LegacyTodoCloseGuard;
import com.kaiwu.module.operation.service.LegacyTodoOpenGuard;
import com.kaiwu.module.operation.service.TodoService;
import com.kaiwu.module.operation.vo.TodoSummaryView;
import com.kaiwu.module.operation.vo.TodoView;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * 统一待办：集中存储在 System 库，状态由来源服务维护（ADR 0034）。
 *
 * <p>读取只针对当前登录用户自己；写入只有业务服务经投递端点调用的 {@link #open} 与 {@link #close}，
 * 收件人没有任何改状态的路径。
 */
@Service("todoService")
@EnableConfigurationProperties(TodoProperties.class)
public class TodoServiceImpl implements TodoService {

    /** 工作台概览最多展示的未处理条数。 */
    private static final int RECENT_LIMIT = 10;

    private static final String OPEN = "OPEN";
    private static final String DONE = "DONE";
    private static final Set<String> QUERY_STATUSES = Set.of(OPEN, DONE, "CANCELLED");

    private static final AtomicLong ID_SEQUENCE = new AtomicLong(System.currentTimeMillis() * 1_000_000L);

    private final TodoRepository repository;
    private final TodoProperties properties;
    private final Clock clock;
    private final LegacyTodoOpenGuard openGuard;
    private final LegacyTodoCloseGuard closeGuard;

    /**
     * 创建服务。
     *
     * @param repository 待办仓储
     * @param properties 待办容量与清理配置
     * @param clock 时钟，便于测试固定当前时间
     */
    public TodoServiceImpl(
            TodoRepository repository,
            TodoProperties properties,
            Clock clock,
            LegacyTodoOpenGuard openGuard,
            LegacyTodoCloseGuard closeGuard) {
        this.repository = repository;
        this.properties = properties;
        this.clock = clock;
        this.openGuard = openGuard;
        this.closeGuard = closeGuard;
    }

    /**
     * 当前用户的待办分页。越界参数直接拒绝，与其它列表接口保持同一语义；状态缺省为 OPEN，只接受三个取值。
     */
    @Override
    public PageResult<TodoView> myTodos(String userId, long current, long size, String status, String projectCode) {
        PageBounds.require(current, size);
        String filterStatus = normalizeStatus(status);
        String filterProject = StringUtils.hasText(projectCode) ? projectCode.trim() : null;
        LocalDateTime now = LocalDateTime.now(clock);
        long total = repository.count(userId, filterStatus, filterProject);
        List<TodoView> records =
                repository.page(userId, filterStatus, filterProject, (current - 1) * size, size).stream()
                        .map(row -> toView(row, now))
                        .toList();
        return new PageResult<>(current, size, total, records);
    }

    /** 工作台概览：未处理数、逾期数与最近若干条未处理待办，逾期按服务端当前时间判定。 */
    @Override
    public TodoSummaryView summary(String userId) {
        LocalDateTime now = LocalDateTime.now(clock);
        return new TodoSummaryView(
                repository.count(userId, OPEN, null),
                repository.countOverdue(userId, now),
                repository.recentOpen(userId, RECENT_LIMIT).stream()
                        .map(row -> toView(row, now))
                        .toList());
    }

    /**
     * 打开待办。校验来源项目存在且启用、处理人是该项目有效成员，防止任一业务服务向平台全体用户灌入待办。
     *
     * <p>容量上限是软限制：检查与写入之间没有加锁，并发打开可能短暂越过上限几条，随后的打开会被拒绝；
     * 上限的目的是挡住失控灌入，不需要精确。已处于 OPEN 的同键更新不占用额度。</p>
     */
    @Override
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public void open(TodoOpenRequest request) {
        TodoRepository.ProjectRef project = requireProject(request.projectCode());
        String bizKey = request.bizKey().trim();
        if (!repository.activeMemberExists(project.id(), request.recipientUserId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "处理人不是该项目的有效成员", "api.common.forbidden");
        }
        LegacyTodoOpenGuard.Reservation reservation = null;
        if (properties.isManagedProtocolEnabled()) {
            reservation = openGuard.prepare(
                    project.projectCode(),
                    bizKey,
                    recipientId(request.recipientUserId()),
                    properties.getMaxOpenPerRecipient());
        } else if (!repository.isOpen(project.projectCode(), bizKey, request.recipientUserId())
                && repository.countOpenByRecipient(project.projectCode(), request.recipientUserId())
                        >= properties.getMaxOpenPerRecipient()) {
            throw new ApiException(HttpStatus.CONFLICT, "该处理人未处理的待办数量已达上限", "api.common.conflict");
        }
        LocalDateTime now = LocalDateTime.now(clock);
        repository.upsertOpen(new TodoRepository.TodoRow(
                nextId(),
                project.id(),
                project.projectCode(),
                bizKey,
                request.recipientUserId(),
                request.title(),
                request.content(),
                // 业务服务并不知道自己的项目 ID，缺省时指向该项目的后台入口。
                StringUtils.hasText(request.linkUrl()) ? request.linkUrl() : "/workspace/" + project.id(),
                OPEN,
                request.dueAt(),
                now,
                null,
                now,
                now));
        if (reservation != null) openGuard.complete(reservation);
    }

    /**
     * 关闭待办。只校验来源项目存在且启用，不要求处理人仍是成员：关闭只会减少待办，
     * 成员被移出项目后，他名下的待办仍应能被业务服务关掉。
     */
    @Override
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public long close(TodoCloseRequest request) {
        TodoRepository.ProjectRef project = requireProject(request.projectCode());
        String result = StringUtils.hasText(request.result()) ? request.result() : DONE;
        LegacyTodoCloseGuard.Reservation reservation = properties.isManagedProtocolEnabled()
                ? closeGuard.prepare(
                        project.projectCode(),
                        request.bizKey().trim(),
                        StringUtils.hasText(request.recipientUserId()) ? recipientId(request.recipientUserId()) : null)
                : null;
        long changed = repository.close(
                project.projectCode(),
                request.bizKey().trim(),
                request.recipientUserId(),
                result,
                LocalDateTime.now(clock));
        if (reservation != null) closeGuard.complete(reservation, changed);
        return changed;
    }

    /** 只在新共享协议中接受规范的正数 BIGINT 用户 ID。 */
    private static long recipientId(String value) {
        try {
            if (value == null || !value.matches("[1-9][0-9]{0,18}")) throw new NumberFormatException();
            return Long.parseLong(value);
        } catch (NumberFormatException ex) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "处理人 ID 无效", "api.common.badRequest");
        }
    }

    /** 校验来源项目存在且启用，否则 404。投递来源必须是平台登记且启用的项目。 */
    private TodoRepository.ProjectRef requireProject(String projectCode) {
        return repository
                .enabledProjectByCode(projectCode.trim())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "来源项目不存在或未启用", "api.common.notFound"));
    }

    /** 规范化状态筛选：空值取 OPEN，大小写不敏感，不在三个取值内直接拒绝而不是静默忽略。 */
    private static String normalizeStatus(String status) {
        if (!StringUtils.hasText(status)) {
            return OPEN;
        }
        String normalized = status.trim().toUpperCase(java.util.Locale.ROOT);
        if (!QUERY_STATUSES.contains(normalized)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "待办状态只能是 OPEN、DONE 或 CANCELLED", "api.common.badRequest");
        }
        return normalized;
    }

    /** 仓储行转视图；逾期仅对 OPEN 且设置了已过期截止时间的待办成立。 */
    private static TodoView toView(TodoRepository.TodoRow row, LocalDateTime now) {
        boolean overdue =
                OPEN.equals(row.status()) && row.dueAt() != null && row.dueAt().isBefore(now);
        return new TodoView(
                row.id(),
                row.projectId(),
                row.projectCode(),
                row.title(),
                row.content(),
                row.linkUrl(),
                row.status(),
                row.dueAt(),
                overdue,
                row.openedAt(),
                row.closedAt());
    }

    /** 生成下一个待办 ID：毫秒时间戳放大后自增，单进程内单调。 */
    private static String nextId() {
        return String.valueOf(ID_SEQUENCE.incrementAndGet());
    }
}
