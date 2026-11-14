package com.kaiwu.module.operation.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.LongIdGenerator;
import com.kaiwu.module.operation.config.TodoProperties;
import com.kaiwu.module.operation.dto.ManagedTodoRequest;
import com.kaiwu.module.operation.mapper.ManagedTodoLockMapper;
import com.kaiwu.module.operation.mapper.ManagedTodoMapper;
import com.kaiwu.module.operation.protocol.ManagedTodoDigest;
import com.kaiwu.module.operation.protocol.ManagedTodoTransition;
import com.kaiwu.module.operation.protocol.ManagedTodoValidation;
import com.kaiwu.module.operation.service.ManagedTodoService;
import com.kaiwu.module.operation.vo.ManagedTodoReceipt;
import com.kaiwu.module.project.model.ProjectServiceCredential;
import com.kaiwu.module.project.service.ProjectServiceCredentials;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.HexFormat;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

/** C5 身份限定的受管待办服务；旧新写入须共同启用共享锁协议。 */
@Service
public class ManagedTodoServiceImpl implements ManagedTodoService {
    private final ProjectServiceCredentials credentials;
    private final ManagedTodoLockMapper locks;
    private final ManagedTodoMapper records;
    private final TodoProperties properties;
    private final Clock clock;
    private final Duration futureTolerance;

    /** 显式配置可容忍的未来时钟偏差；日志不包含凭据和投递正文。 */
    public ManagedTodoServiceImpl(
            ProjectServiceCredentials credentials,
            ManagedTodoLockMapper locks,
            ManagedTodoMapper records,
            TodoProperties properties,
            Clock clock,
            @Value("${kaiwu.todo.managed-future-tolerance-seconds:30}") long toleranceSeconds) {
        if (toleranceSeconds < 0 || toleranceSeconds > 300)
            throw new IllegalArgumentException("invalid clock tolerance");
        this.credentials = credentials;
        this.locks = locks;
        this.records = records;
        this.properties = properties;
        this.clock = clock;
        this.futureTolerance = Duration.ofSeconds(toleranceSeconds);
    }

    /** 投递以项目、生产者、业务键和收件人隔离，变更、占用与额度同事务。 */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public ManagedTodoReceipt put(String authorization, ManagedTodoRequest request) {
        ProjectServiceCredential caller = credentials.authenticateScopeBearer(authorization, "todo:managed");
        requireEnabled();
        if (request == null || request.terminal() == null || request.sequence() == null) throw badRequest();
        long projectId = positiveLong(caller.projectId());
        long recipient = positiveLong(request.recipientUserId());
        String project = records.activeProjectCode(projectId);
        if (project == null || !project.equals(request.projectCode())) throw forbidden();
        var op = new ManagedTodoDigest.Operation(
                project,
                caller.serviceCode(),
                request.bizKey(),
                recipient,
                request.sequence(),
                request.state(),
                request.terminal(),
                request.operationCreatedAt(),
                request.title(),
                request.content(),
                request.linkUrl(),
                request.dueAt());
        try {
            ManagedTodoValidation.validate(op, clock.instant(), futureTolerance);
            validateLink(projectId, op.linkUrl());
        } catch (IllegalArgumentException ex) {
            throw badRequest();
        }
        byte[] digest = ManagedTodoDigest.sha256(op);
        locks.ensureBusinessKey(project, op.bizKey());
        if (locks.lockBusinessKey(project, op.bizKey()) == null) throw unavailable();
        locks.ensureQuota(project, recipient);
        Long quota = locks.lockQuota(project, recipient);
        if (quota == null || quota < 0) throw unavailable();
        String kind = locks.lockGuard(project, op.bizKey(), recipient);
        if (kind == null) {
            if (locks.countLegacyKeyForUpdate(project, op.bizKey(), recipient) != 0
                    || locks.countManagedKeyForUpdate(project, op.bizKey(), recipient) != 0) throw unavailable();
            locks.insertGuard(project, op.bizKey(), recipient, "MANAGED");
        } else if (kind.equals("LEGACY")) throw conflict("api.todo.legacyConflict");
        else if (!kind.equals("MANAGED") || locks.countLegacyKeyForUpdate(project, op.bizKey(), recipient) != 0)
            throw unavailable();
        Map<String, Object> current = records.lockProjection(project, caller.serviceCode(), op.bizKey(), recipient);
        ManagedTodoTransition.Stored stored = current == null || current.isEmpty() ? null : stored(current);
        var decision = ManagedTodoTransition.decide(stored, op.sequence(), op.state(), op.terminal(), digest);
        if (decision == ManagedTodoTransition.Result.TERMINAL_CONFLICT) throw conflict("api.todo.terminalConflict");
        if (decision == ManagedTodoTransition.Result.SEQUENCE_CONFLICT) throw conflict("api.todo.sequenceConflict");
        if (decision != ManagedTodoTransition.Result.APPLIED) return receipt(decision.name(), stored);
        long actual;
        try {
            actual = Math.addExact(
                    locks.countLegacyOpenForUpdate(project, recipient),
                    locks.countManagedOpenForUpdate(project, recipient));
        } catch (ArithmeticException ex) {
            throw unavailable();
        }
        if (actual != quota) throw unavailable();
        boolean wasOpen = stored != null && stored.state().equals("OPEN");
        boolean opens = op.state().equals("OPEN");
        if (opens) {
            if (!"ENABLED".equals(records.lockUserStatus(recipient))
                    || !"ACTIVE".equals(records.lockMemberStatus(projectId, recipient))) throw forbidden();
            if (!wasOpen && quota >= properties.getMaxOpenPerRecipient())
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "该处理人未处理的待办数量已达上限", "api.todo.openLimitExceeded");
        }
        long next = quota + (opens && !wasOpen ? 1 : (!opens && wasOpen ? -1 : 0));
        if (next < 0 || (opens && !wasOpen && quota == Long.MAX_VALUE)) throw unavailable();
        LocalDateTime now = LocalDateTime.ofInstant(clock.instant().truncatedTo(ChronoUnit.MICROS), ZoneOffset.UTC);
        long id = stored == null ? positiveLong(LongIdGenerator.nextId()) : asLong(value(current, "id"));
        String link = op.linkUrl() == null ? "/workspace/" + projectId : op.linkUrl();
        var row = new ManagedTodoMapper.Row(
                id,
                projectId,
                project,
                caller.serviceCode(),
                op.bizKey(),
                recipient,
                op.sequence(),
                op.state(),
                op.terminal(),
                digest,
                utc(op.operationCreatedAt()),
                op.title(),
                op.content(),
                link,
                utc(op.dueAt()),
                now);
        if ((stored == null ? records.insert(row) : records.update(row)) != 1) throw unavailable();
        if (next != quota && locks.replaceQuota(project, recipient, quota, next) != 1) throw unavailable();
        return new ManagedTodoReceipt(
                "APPLIED",
                op.sequence(),
                op.state(),
                op.terminal(),
                HexFormat.of().formatHex(digest));
    }

    /** 只查询凭据项目、生产者和指定单收件人投影的回执。 */
    @Transactional(readOnly = true)
    public ManagedTodoReceipt receipt(String authorization, String key, String recipientId) {
        var caller = credentials.authenticateScopeBearer(authorization, "todo:managed");
        requireEnabled();
        long recipient = positiveLong(recipientId);
        String project = records.activeProjectCode(positiveLong(caller.projectId()));
        if (project == null) throw forbidden();
        if (key == null || !key.matches("[A-Za-z0-9][A-Za-z0-9:_./#-]{0,127}")) throw badRequest();
        var row = records.receipt(project, caller.serviceCode(), key, recipient);
        if (row == null || row.isEmpty())
            throw new ApiException(HttpStatus.NOT_FOUND, "待办回执不存在", "api.common.notFound");
        return receipt("STORED", stored(row));
    }
    /** 只允许跳转到当前项目宿主路径，route 参数由宿主再次校验。 */
    private static void validateLink(long projectId, String link) {
        if (link == null) return;
        String base = "/workspace/" + projectId;
        if ((!link.equals(base) && !link.startsWith(base + "?route="))
                || link.indexOf('\\') >= 0
                || link.indexOf('#') >= 0
                || link.codePoints().anyMatch(Character::isISOControl)
                || link.toLowerCase(java.util.Locale.ROOT).contains("%25"))
            throw new IllegalArgumentException("invalid link");
    }
    /** 只接受规范正数 BIGINT，避免字符串截断或不同写法造成键冲突。 */
    private static long positiveLong(String value) {
        try {
            if (value == null || !value.matches("[1-9][0-9]{0,18}")) throw new NumberFormatException();
            return Long.parseLong(value);
        } catch (NumberFormatException ex) {
            throw badRequest();
        }
    }
    /** 将 JDBC 返回的摘要和状态还原为受控版本信息。 */
    private static ManagedTodoTransition.Stored stored(Map<String, Object> row) {
        Object flag = value(row, "terminal");
        boolean terminal = flag instanceof Boolean b ? b : asLong(flag) != 0;
        return new ManagedTodoTransition.Stored(
                asLong(value(row, "operationSequence")), String.valueOf(value(row, "state")), terminal, (byte[])
                        value(row, "payloadDigest"));
    }
    /** 解析 JDBC 大小写可能不同的列别名，不允许缺失字段。 */
    private static Object value(Map<String, Object> row, String key) {
        return row.entrySet().stream()
                .filter(e -> e.getKey().equalsIgnoreCase(key))
                .map(Map.Entry::getValue)
                .filter(java.util.Objects::nonNull)
                .findFirst()
                .orElseThrow(ManagedTodoServiceImpl::unavailable);
    }
    /** 数值字段统一使用 JDBC Number，避免精度损失。 */
    private static long asLong(Object value) {
        if (!(value instanceof Number n)) throw unavailable();
        return n.longValue();
    }
    /** 数据库存 UTC 本地值；输入已验证微秒精度。 */
    private static LocalDateTime utc(Instant value) {
        return value == null ? null : LocalDateTime.ofInstant(value, ZoneOffset.UTC);
    }
    /** 回执严格只含协议状态。 */
    private static ManagedTodoReceipt receipt(String disposition, ManagedTodoTransition.Stored state) {
        return new ManagedTodoReceipt(
                disposition,
                state.sequence(),
                state.state(),
                state.terminal(),
                HexFormat.of().formatHex(state.digest()));
    }
    /** 混合版本保护未打开前不执行任何受管读写。 */
    private void requireEnabled() {
        if (!properties.isManagedProtocolEnabled()) throw unavailable();
    }
    /** 统一格式错误。 */
    private static ApiException badRequest() {
        return new ApiException(HttpStatus.BAD_REQUEST, "待办请求无效", "api.common.badRequest");
    }
    /** 统一身份或成员无权错误。 */
    private static ApiException forbidden() {
        return new ApiException(HttpStatus.FORBIDDEN, "无权访问该项目待办", "api.common.forbidden");
    }
    /** 同序冲突或终态重开冲突。 */
    private static ApiException conflict(String key) {
        return new ApiException(HttpStatus.CONFLICT, "待办版本冲突", key);
    }
    /** 配额不一致或协议未启用时失败关闭。 */
    private static ApiException unavailable() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "待办服务暂不可用", "api.common.serviceUnavailable");
    }
}
