package com.kaiwu.module.i18n;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.i18n.dto.I18nMessageSaveRequest;
import com.kaiwu.module.i18n.vo.I18nCatalogView;
import com.kaiwu.module.i18n.vo.I18nLocaleView;
import com.kaiwu.module.i18n.vo.I18nMessageView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Objects;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
public class I18nController {

    private final I18nService service;

    public I18nController(I18nService service) {
        this.service = service;
    }

    @GetMapping("/api/public/i18n/catalog")
    public ResponseEntity<Result<I18nCatalogView>> publicCatalog(
            @RequestParam(defaultValue = "zh-CN") String locale,
            @RequestParam(required = false) Long revision,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
        return catalogResponse(service.catalog(locale, true), revision, ifNoneMatch);
    }

    @GetMapping("/api/i18n/catalog")
    public ResponseEntity<Result<I18nCatalogView>> catalog(
            @RequestParam(defaultValue = "zh-CN") String locale,
            @RequestParam(required = false) Long revision,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
        StarterContext.require();
        return catalogResponse(service.catalog(locale, false), revision, ifNoneMatch);
    }

    @GetMapping("/api/i18n/resources")
    @RequirePermission("system:i18n:list")
    public Result<List<I18nMessageView>> messages() {
        return Result.ok(service.messages());
    }

    @GetMapping("/api/i18n/locales")
    public Result<List<I18nLocaleView>> locales(@RequestParam(defaultValue = "zh-CN") String locale) {
        StarterContext.require();
        return Result.ok(service.locales(locale));
    }

    @PostMapping("/api/i18n/resources")
    @RequirePermission("system:i18n:save")
    public Result<I18nMessageView> save(
            @Valid @RequestBody I18nMessageSaveRequest request, HttpServletRequest servletRequest) {
        return Result.ok(service.save(request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    /**
     * 导出待翻译内容（三个 Sheet：资源 / 菜单 / 字典）。
     *
     * <p>复用列表权限码：导出的是与列表相同的内容，不新增导出专用权限。</p>
     */
    @GetMapping("/api/i18n/translations/export")
    @RequirePermission("system:i18n:list")
    public ResponseEntity<byte[]> exportTranslations(@RequestParam String locale) {
        byte[] workbook = service.exportTranslations(locale);
        String filename = "kaiwu-i18n-" + locale + ".xlsx";
        return ResponseEntity.ok()
                .header(
                        HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment()
                                .filename(filename, StandardCharsets.UTF_8)
                                .build()
                                .toString())
                .contentType(
                        MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(workbook);
    }

    /** 导入译文；逐行独立处理，失败行汇总回报而不中断整批。 */
    @PostMapping(value = "/api/i18n/translations/import", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @RequirePermission("system:i18n:save")
    public Result<I18nService.TranslationImportResult> importTranslations(
            @RequestParam String locale, @RequestParam("file") MultipartFile file, HttpServletRequest servletRequest)
            throws IOException {
        return Result.ok(service.importTranslations(
                locale, file.getBytes(), StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    @DeleteMapping("/api/i18n/resources/{id}")
    @RequirePermission("system:i18n:delete")
    public Result<Void> delete(@PathVariable String id, @RequestParam long version, HttpServletRequest servletRequest) {
        service.delete(id, version, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    private ResponseEntity<Result<I18nCatalogView>> catalogResponse(
            I18nCatalogView catalog, Long clientRevision, String ifNoneMatch) {
        String etag = "\"i18n-" + catalog.locale() + '-' + catalog.revision() + "\"";
        if (Objects.equals(clientRevision, catalog.revision()) || etag.equals(ifNoneMatch)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(etag).build();
        }
        return ResponseEntity.ok().eTag(etag).body(Result.ok(catalog));
    }
}
