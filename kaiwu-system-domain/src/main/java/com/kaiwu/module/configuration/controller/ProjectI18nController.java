package com.kaiwu.module.configuration.controller;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.configuration.service.I18nService;
import com.kaiwu.module.i18n.dto.I18nMessageSaveRequest;
import com.kaiwu.module.i18n.vo.I18nMessageView;
import com.kaiwu.port.ProjectI18nAccessPort;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

/**
 * 业务项目的国际化资源管理（ADR 0037）。
 *
 * <p>权限是目标项目的有效项目管理员，不要求平台级 {@code system:i18n:*}；
 * 每个入口都先过 {@link ProjectI18nAccessPort}，资源按项目作用域读写，碰不到平台资源。</p>
 */
@RestController
@RequestMapping("/api/projects/{projectId}/i18n")
public class ProjectI18nController {

    private final I18nService service;
    private final ProjectI18nAccessPort access;

    public ProjectI18nController(I18nService service, ProjectI18nAccessPort access) {
        this.service = service;
        this.access = access;
    }

    @GetMapping("/resources")
    public Result<List<I18nMessageView>> messages(@PathVariable String projectId) {
        access.requireProjectAdmin(projectId, StarterContext.require().userId());
        return Result.ok(service.projectMessages(projectId));
    }

    @PostMapping("/resources")
    public Result<I18nMessageView> save(
            @PathVariable String projectId,
            @Valid @RequestBody I18nMessageSaveRequest request,
            HttpServletRequest servletRequest) {
        var actor = StarterContext.require();
        access.requireProjectAdmin(projectId, actor.userId());
        return Result.ok(service.saveProjectMessage(projectId, request, actor, RequestMetadata.from(servletRequest)));
    }

    @DeleteMapping("/resources/{id}")
    public Result<Void> delete(
            @PathVariable String projectId,
            @PathVariable String id,
            @RequestParam long version,
            HttpServletRequest servletRequest) {
        var actor = StarterContext.require();
        access.requireProjectAdmin(projectId, actor.userId());
        service.deleteProjectMessage(projectId, id, version, actor, RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    @GetMapping("/translations/export")
    public ResponseEntity<byte[]> exportTranslations(@PathVariable String projectId, @RequestParam String locale) {
        access.requireProjectAdmin(projectId, StarterContext.require().userId());
        byte[] workbook = service.exportProjectTranslations(projectId, locale);
        return ResponseEntity.ok()
                .header(
                        HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment()
                                .filename("kaiwu-i18n-project-" + locale + ".xlsx", StandardCharsets.UTF_8)
                                .build()
                                .toString())
                .contentType(
                        MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(workbook);
    }

    @PostMapping(value = "/translations/import", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Result<I18nService.TranslationImportResult> importTranslations(
            @PathVariable String projectId,
            @RequestParam String locale,
            @RequestParam("file") MultipartFile file,
            HttpServletRequest servletRequest)
            throws IOException {
        var actor = StarterContext.require();
        access.requireProjectAdmin(projectId, actor.userId());
        return Result.ok(service.importProjectTranslations(
                projectId, locale, file.getBytes(), actor, RequestMetadata.from(servletRequest)));
    }
}
