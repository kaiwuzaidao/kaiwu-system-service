package com.kaiwu.module.metadata;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.metadata.dto.ConfigSaveRequest;
import com.kaiwu.module.metadata.dto.DictItemSaveRequest;
import com.kaiwu.module.metadata.dto.DictTypeSaveRequest;
import com.kaiwu.module.metadata.dto.SortOrderRequest;
import com.kaiwu.module.metadata.vo.*;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.*;

@RestController
public class MetadataController {

    private final MetadataService service;

    public MetadataController(MetadataService service) {
        this.service = service;
    }

    @GetMapping("/api/metadata/configs")
    @RequirePermission("system:config:list")
    public Result<List<ConfigView>> configs(@RequestParam(defaultValue = "0") String scopeId) {
        return Result.ok(service.configs(scopeId));
    }

    @PostMapping("/api/metadata/configs")
    @RequirePermission("system:config:save")
    public Result<ConfigView> saveConfig(
            @RequestParam(defaultValue = "0") String scopeId,
            @Valid @RequestBody ConfigSaveRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(
                service.saveConfig(scopeId, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    /** 删除参数配置；不可逆。 */
    @DeleteMapping("/api/metadata/configs/{id}")
    @RequirePermission("system:config:delete")
    public Result<Void> deleteConfig(
            @PathVariable String id,
            @RequestParam(defaultValue = "0") String scopeId,
            HttpServletRequest servletRequest) {
        service.deleteConfig(scopeId, id, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    @GetMapping("/api/metadata/dicts")
    @RequirePermission("system:dict:list")
    public Result<List<DictTypeView>> dictTypes(@RequestParam(defaultValue = "0") String scopeId) {
        return Result.ok(service.dictTypes(scopeId));
    }

    @PostMapping("/api/metadata/dicts")
    @RequirePermission("system:dict:save")
    public Result<DictTypeView> saveDictType(
            @RequestParam(defaultValue = "0") String scopeId,
            @Valid @RequestBody DictTypeSaveRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(
                service.saveDictType(scopeId, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    /** 按拖拽结果重排字典类型；复用保存权限，不新增排序专用权限码。 */
    @PostMapping("/api/metadata/dicts/sort")
    @RequirePermission("system:dict:save")
    public Result<Void> sortDictTypes(
            @RequestParam(defaultValue = "0") String scopeId,
            @Valid @RequestBody SortOrderRequest request,
            HttpServletRequest servletRequest) {
        service.sortDictTypes(scopeId, request.ids(), StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    /** 删除字典类型，连同其下全部字典项。 */
    @DeleteMapping("/api/metadata/dicts/{id}")
    @RequirePermission("system:dict:delete")
    public Result<Void> deleteDictType(
            @PathVariable String id,
            @RequestParam(defaultValue = "0") String scopeId,
            HttpServletRequest servletRequest) {
        service.deleteDictType(scopeId, id, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    @GetMapping("/api/metadata/dicts/{typeId}/items")
    @RequirePermission("system:dict:list")
    public Result<List<DictItemView>> dictItems(
            @PathVariable String typeId, @RequestParam(defaultValue = "0") String scopeId) {
        return Result.ok(service.dictItems(scopeId, typeId));
    }

    @PostMapping("/api/metadata/dicts/{typeId}/items")
    @RequirePermission("system:dict:save")
    public Result<DictItemView> saveDictItem(
            @PathVariable String typeId,
            @RequestParam(defaultValue = "0") String scopeId,
            @Valid @RequestBody DictItemSaveRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(service.saveDictItem(
                scopeId, typeId, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    /** 按拖拽结果重排某字典下的字典项。 */
    @PostMapping("/api/metadata/dicts/{typeId}/items/sort")
    @RequirePermission("system:dict:save")
    public Result<Void> sortDictItems(
            @PathVariable String typeId,
            @RequestParam(defaultValue = "0") String scopeId,
            @Valid @RequestBody SortOrderRequest request,
            HttpServletRequest servletRequest) {
        service.sortDictItems(
                scopeId, typeId, request.ids(), StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    /** 删除单个字典项；已被业务数据引用的值删除后按未知值原样显示。 */
    @DeleteMapping("/api/metadata/dicts/{typeId}/items/{itemId}")
    @RequirePermission("system:dict:delete")
    public Result<Void> deleteDictItem(
            @PathVariable String typeId,
            @PathVariable String itemId,
            @RequestParam(defaultValue = "0") String scopeId,
            HttpServletRequest servletRequest) {
        service.deleteDictItem(scopeId, typeId, itemId, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    @GetMapping("/api/current/projects/{projectId}/configs")
    public Result<List<EffectiveConfigView>> effectiveConfigs(
            @PathVariable String projectId,
            @RequestHeader(name = "Accept-Language", required = false) String language) {
        return Result.ok(
                service.effectiveConfigs(projectId, StarterContext.require().userId(), language));
    }

    @GetMapping("/api/current/projects/{projectId}/dicts/{dictCode}")
    public Result<EffectiveDictView> effectiveDict(
            @PathVariable String projectId,
            @PathVariable String dictCode,
            @RequestHeader(value = HttpHeaders.ACCEPT_LANGUAGE, required = false) String language) {
        return Result.ok(service.effectiveDict(
                projectId, dictCode, StarterContext.require().userId(), language));
    }

    /**
     * 平台字典：只返回 scope=0 global 字典，任何登录用户可读，无需项目上下文与权限码。
     * 前端 useDict 走此端点，业务字典若需项目覆盖再走上面 effectiveDict。
     */
    @GetMapping("/api/metadata/dicts/effective/{dictCode}")
    public Result<EffectiveDictView> platformDict(
            @PathVariable String dictCode, @RequestHeader(name = "Accept-Language", required = false) String language) {
        return Result.ok(service.platformDict(dictCode, language));
    }
}
