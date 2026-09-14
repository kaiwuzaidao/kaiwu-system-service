package com.kaiwu.module.user;

import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.user.dto.ResetPasswordRequest;
import com.kaiwu.module.user.dto.UserBatchStatusRequest;
import com.kaiwu.module.user.dto.UserCreateRequest;
import com.kaiwu.module.user.dto.UserStatusRequest;
import com.kaiwu.module.user.dto.UserUpdateRequest;
import com.kaiwu.module.user.vo.UserImportResult;
import com.kaiwu.module.user.vo.UserView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.io.IOException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * 平台用户管理接口。
 */
@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;
    private final UserBatchService userBatchService;

    public UserController(UserService userService, UserBatchService userBatchService) {
        this.userService = userService;
        this.userBatchService = userBatchService;
    }

    @GetMapping
    @RequirePermission("system:user:list")
    public Result<PageResult<UserView>> page(
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "10") long size) {
        return Result.ok(userService.page(keyword, current, size));
    }

    @PostMapping
    @RequirePermission("system:user:create")
    public Result<UserView> create(@Valid @RequestBody UserCreateRequest request, HttpServletRequest servletRequest) {
        return Result.ok(userService.create(request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    @PutMapping("/{id}")
    @RequirePermission("system:user:update")
    public Result<UserView> update(
            @PathVariable String id, @Valid @RequestBody UserUpdateRequest request, HttpServletRequest servletRequest) {
        return Result.ok(
                userService.update(id, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    /** 启停单个用户；停用同时撤销其全部在线会话。 */
    @PutMapping("/{id}/status")
    @RequirePermission("system:user:status")
    public Result<UserView> updateStatus(
            @PathVariable String id, @Valid @RequestBody UserStatusRequest request, HttpServletRequest servletRequest) {
        return Result.ok(userService.updateStatus(
                id, request.status(), StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    @PostMapping("/{id}/reset-password")
    @RequirePermission("system:user:reset-password")
    public Result<Void> resetPassword(
            @PathVariable String id,
            @Valid @RequestBody ResetPasswordRequest request,
            HttpServletRequest servletRequest) {
        userService.resetPassword(id, request, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    @GetMapping("/import-template")
    @RequirePermission("system:user:create")
    public ResponseEntity<byte[]> importTemplate(
            @RequestHeader(value = HttpHeaders.ACCEPT_LANGUAGE, required = false) String language) {
        boolean english = english(language);
        return workbook(english ? "user-import-template.xlsx" : "用户导入模板.xlsx", userBatchService.template(language));
    }

    /** 导出当前筛选结果为 Excel；复用列表权限码，不新增导出专用权限。 */
    @GetMapping("/export")
    @RequirePermission("system:user:list")
    public ResponseEntity<byte[]> exportUsers(
            @RequestParam(required = false) String keyword,
            @RequestHeader(value = HttpHeaders.ACCEPT_LANGUAGE, required = false) String language,
            HttpServletRequest servletRequest) {
        return workbook(
                english(language) ? "platform-users.xlsx" : "平台用户.xlsx",
                userBatchService.exportUsers(
                        keyword, StarterContext.require(), RequestMetadata.from(servletRequest), language));
    }

    @PostMapping(value = "/import", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @RequirePermission("system:user:create")
    public Result<UserImportResult> importUsers(
            @RequestParam("file") MultipartFile file, HttpServletRequest servletRequest) throws IOException {
        return Result.ok(userBatchService.importUsers(
                file.getBytes(), StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    /** 批量启停用户。 */
    @PutMapping("/batch-status")
    @RequirePermission("system:user:status")
    public Result<Void> batchStatus(
            @Valid @RequestBody UserBatchStatusRequest request, HttpServletRequest servletRequest) {
        userBatchService.updateStatuses(
                request.userIds(), request.status(), StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    private static ResponseEntity<byte[]> workbook(String filename, byte[] bytes) {
        return ResponseEntity.ok()
                .header(
                        HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename*=UTF-8''"
                                + java.net.URLEncoder.encode(filename, java.nio.charset.StandardCharsets.UTF_8))
                .contentType(
                        MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(bytes);
    }

    private static boolean english(String language) {
        return language != null && language.toLowerCase(java.util.Locale.ROOT).startsWith("en");
    }
}
