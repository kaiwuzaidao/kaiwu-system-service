package com.kaiwu.module.user;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.audit.AuditService;
import com.kaiwu.module.org.OrgRepository;
import com.kaiwu.module.org.OrgService;
import com.kaiwu.module.org.dto.UserDepartmentRequest;
import com.kaiwu.module.user.dto.UserCreateRequest;
import com.kaiwu.module.user.vo.UserImportError;
import com.kaiwu.module.user.vo.UserImportResult;
import com.kaiwu.module.user.vo.UserView;
import com.kaiwu.starter.KaiwuContext;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class UserBatchService {

    private static final int MAX_FILE_BYTES = 10 * 1024 * 1024;
    /**
     * 单次导出行数上限。取 20000 而不是与导入的 5000 对齐：导入是人工维护的批次，
     * 导出通常期望拿到完整名单，上限只用于兜住内存。平台用户量级远低于该值，
     * 真实触发说明该按条件分批导出。
     */
    private static final int MAX_EXPORT_ROWS = 20_000;

    private final UserService userService;
    private final UserRepository repository;
    private final OrgRepository orgRepository;
    private final OrgService orgService;
    private final UserWorkbookCodec codec;
    private final AuditService auditService;

    public UserBatchService(
            UserService userService,
            UserRepository repository,
            OrgRepository orgRepository,
            OrgService orgService,
            UserWorkbookCodec codec,
            AuditService auditService) {
        this.userService = userService;
        this.repository = repository;
        this.orgRepository = orgRepository;
        this.orgService = orgService;
        this.codec = codec;
        this.auditService = auditService;
    }

    public byte[] template() {
        return codec.exportUsers(List.of());
    }

    public byte[] template(String language) {
        return codec.exportUsers(List.of(), language);
    }

    /**
     * 导出当前筛选结果。
     *
     * <p>上限存在的原因：结果集会整体驻留内存后再交给 POI，无上限的全表查询在用户量增长后
     * 会 OOM（SXSSF 的流式写只降低写出侧内存，降不了数据源侧）。超限时要求先筛选，
     * 而不是静默截断——少数据比报错更难发现。
     *
     * <p>导出是数据外泄面：批量带走全量用户名单不会经过任何单条写操作审计，
     * 因此在成功导出后必须留痕，记录导出人、筛选条件和行数。
     *
     * @param keyword 与列表页一致的筛选关键字
     */
    public byte[] exportUsers(String keyword, KaiwuContext actor, RequestMetadata metadata) {
        return exportUsers(keyword, actor, metadata, "zh-CN");
    }

    /**
     * 导出用户为 Excel。
     *
     * <p>筛选条件与列表页一致，导出即「当前筛选结果」；行数超上限直接报错而不是静默截断，
     * 密码列一律留空。列顺序与导入模板一致，导出文件可改后直接回传导入。</p>
     */
    public byte[] exportUsers(String keyword, KaiwuContext actor, RequestMetadata metadata, String language) {
        // 多取一行用于判断是否超限。
        List<UserView> users = repository.listForExport(keyword, MAX_EXPORT_ROWS + 1);
        if (users.size() > MAX_EXPORT_ROWS) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "导出结果超过 " + MAX_EXPORT_ROWS + " 条，请先用用户名或显示名筛选后再导出",
                    "api.user.export.tooManyRows",
                    java.util.Map.of("limit", MAX_EXPORT_ROWS));
        }
        byte[] workbook = codec.exportUsers(users, language);
        auditService.recordOperation(
                actor,
                "user",
                "EXPORT_USERS",
                "/api/users/export",
                "rows=" + users.size() + ",keyword=" + (StringUtils.hasText(keyword) ? keyword.trim() : "-"),
                metadata);
        return workbook;
    }

    /** 从 Excel 批量导入用户；逐行校验，失败行汇总返回而不是中断整批。 */
    public UserImportResult importUsers(byte[] bytes, KaiwuContext actor, RequestMetadata metadata) {
        if (bytes.length == 0 || bytes.length > MAX_FILE_BYTES) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Excel 文件大小必须在 1B 到 10MB 之间", "api.user.import.fileSize");
        }
        List<UserWorkbookCodec.ImportRow> rows = codec.readImport(bytes);
        List<UserImportError> errors = new ArrayList<>();
        int succeeded = 0;
        for (UserWorkbookCodec.ImportRow row : rows) {
            try {
                validate(row);
                List<String> codes = splitCodes(row.departmentCodes());
                List<String> departmentIds = orgRepository.findDepartmentIdsByCodes(codes);
                if (departmentIds.size() != codes.size()) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "存在未知部门编码", "api.user.import.unknownDepartment");
                }
                UserView user = userService.create(
                        new UserCreateRequest(
                                row.username(), row.displayName(), blankToNull(row.email()), row.password()),
                        actor,
                        metadata);
                if (!departmentIds.isEmpty()) {
                    orgService.assignDepartments(user.id(), new UserDepartmentRequest(departmentIds), actor, metadata);
                }
                if ("DISABLED".equals(normalizeStatus(row.status()))) {
                    userService.updateStatus(user.id(), "DISABLED", actor, metadata);
                }
                succeeded++;
            } catch (Exception exception) {
                String fallback = StringUtils.hasText(exception.getMessage()) ? exception.getMessage() : "导入失败";
                if (exception instanceof ApiException apiException) {
                    errors.add(new UserImportError(
                            row.rowNumber(),
                            row.username(),
                            fallback,
                            apiException.getMessageKey(),
                            apiException.getMessageArgs()));
                } else {
                    errors.add(new UserImportError(
                            row.rowNumber(), row.username(), fallback, "api.user.import.failed", null));
                }
            }
        }
        // 每个用户已由 userService.create 留下 CREATE_USER 明细；这里补一条批次汇总，
        // 否则无法把散落的明细归到同一次导入，也看不到失败了多少行。
        auditService.recordOperation(
                actor,
                "user",
                "IMPORT_USERS",
                "/api/users/import",
                "total=" + rows.size() + ",succeeded=" + succeeded + ",failed=" + errors.size(),
                metadata);
        return new UserImportResult(rows.size(), succeeded, errors.size(), errors);
    }

    /** 批量启停用户；停用的用户会被同时下线。 */
    public void updateStatuses(List<String> userIds, String status, KaiwuContext actor, RequestMetadata metadata) {
        LinkedHashSet<String> targets = new LinkedHashSet<>(userIds);
        targets.forEach(id -> userService.updateStatus(id, status, actor, metadata));
        // 同上：明细在 CHANGE_USER_STATUS，这里补批次汇总。
        auditService.recordOperation(
                actor,
                "user",
                "BATCH_CHANGE_USER_STATUS",
                "/api/users/batch-status",
                "count=" + targets.size() + ",status=" + status,
                metadata);
    }

    private static void validate(UserWorkbookCodec.ImportRow row) {
        if (!row.username().matches("[A-Za-z0-9._-]{3,64}")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "用户名格式不正确", "api.user.import.usernameInvalid");
        }
        if (!StringUtils.hasText(row.displayName()) || row.displayName().length() > 100) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "姓名不能为空且最多 100 字", "api.user.import.displayNameInvalid");
        }
        if (row.password().length() < 12 || row.password().length() > 72) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "初始密码长度必须为 12-72 位", "api.user.import.passwordInvalid");
        }
        normalizeStatus(row.status());
    }

    private static String normalizeStatus(String status) {
        String value = StringUtils.hasText(status) ? status.trim().toUpperCase(Locale.ROOT) : "ENABLED";
        if (!"ENABLED".equals(value) && !"DISABLED".equals(value)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "状态只能是 ENABLED 或 DISABLED", "api.user.import.statusInvalid");
        }
        return value;
    }

    private static List<String> splitCodes(String value) {
        if (!StringUtils.hasText(value)) return List.of();
        return new ArrayList<>(Arrays.stream(value.split(","))
                .map(String::trim)
                .filter(StringUtils::hasText)
                .collect(java.util.stream.Collectors.toCollection(LinkedHashSet::new)));
    }

    private static String blankToNull(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }
}
