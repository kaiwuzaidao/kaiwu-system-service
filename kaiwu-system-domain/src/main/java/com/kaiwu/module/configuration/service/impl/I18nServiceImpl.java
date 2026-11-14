package com.kaiwu.module.configuration.service.impl;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.I18nService;
import com.kaiwu.module.i18n.dto.I18nMessageSaveRequest;
import com.kaiwu.module.i18n.vo.I18nCatalogView;
import com.kaiwu.module.i18n.vo.I18nLocaleView;
import com.kaiwu.module.i18n.vo.I18nMessageView;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 国际化应用服务 façade。
 *
 * <p>对 Controller 和其它领域保持稳定入口；目录查询、资源规则和工作簿处理分别委托给
 * 聚焦的协作者。事务边界留在 façade，确保导入和资源变更中的数据、版本与审计原子提交。</p>
 */
@Service("i18nService")
public class I18nServiceImpl implements I18nService {

    private final I18nCatalogService catalogService;
    private final I18nMessageService messageService;
    private final I18nWorkbookService workbookService;

    public I18nServiceImpl(
            I18nCatalogService catalogService, I18nMessageService messageService, I18nWorkbookService workbookService) {
        this.catalogService = catalogService;
        this.messageService = messageService;
        this.workbookService = workbookService;
    }

    public String defaultLocale() {
        return catalogService.defaultLocale();
    }

    public List<I18nMessageView> messages() {
        return messageService.messages();
    }

    public I18nCatalogView catalog(String locale, boolean publicOnly) {
        return catalogService.catalog(locale, publicOnly);
    }

    /** 引用式国际化写入前的存在性校验（ADR 0013 第 6 节）。 */
    public boolean messageKeyExists(String messageKey) {
        return catalogService.messageKeyExists(messageKey);
    }

    /** 按作用域判断 key 是否可引用；平台作用域只查平台。 */
    @Override
    public boolean messageKeyExists(String scopeId, String messageKey) {
        return isPlatform(scopeId)
                ? catalogService.messageKeyExists(messageKey)
                : catalogService.messageKeyExists(scopeId, messageKey);
    }

    /** 按作用域取解析器；项目作用域叠加项目资源。 */
    @Override
    public LocalizedText resolver(String scopeId, String locale, boolean anonymous) {
        return isPlatform(scopeId)
                ? resolver(locale, anonymous)
                : new LocalizedText(catalogService.projectMessages(scopeId, locale, anonymous));
    }

    /** 业务项目内是否已有该 key。 */
    @Override
    public boolean projectMessageKeyExists(String projectId, String messageKey) {
        return catalogService.projectMessageKeyExists(projectId, messageKey);
    }

    /** 新建业务项目资源。 */
    @Override
    public I18nMessageView createProjectMessage(
            String projectId, I18nMessageSaveRequest request, KaiwuContext actor, RequestMetadata metadata) {
        return messageService.createProjectMessage(projectId, request, actor, metadata);
    }

    @Override
    public List<I18nMessageView> projectMessages(String projectId) {
        return messageService.projectMessages(projectId);
    }

    @Override
    @Transactional
    public I18nMessageView saveProjectMessage(
            String projectId, I18nMessageSaveRequest request, KaiwuContext actor, RequestMetadata metadata) {
        return messageService.saveProjectMessage(projectId, request, actor, metadata);
    }

    @Override
    @Transactional
    public void deleteProjectMessage(
            String projectId, String id, long version, KaiwuContext actor, RequestMetadata metadata) {
        messageService.deleteProjectMessage(projectId, id, version, actor, metadata);
    }

    @Override
    public byte[] exportProjectTranslations(String projectId, String locale) {
        return workbookService.exportProjectTranslations(projectId, locale);
    }

    @Override
    @Transactional
    public TranslationImportResult importProjectTranslations(
            String projectId, String locale, byte[] bytes, KaiwuContext actor, RequestMetadata metadata) {
        return workbookService.importProjectTranslations(projectId, locale, bytes, actor, metadata);
    }

    /** 空、"0" 都视为平台作用域。 */
    private static boolean isPlatform(String scopeId) {
        return scopeId == null || scopeId.isBlank() || "0".equals(scopeId);
    }

    /**
     * 取一次目录快照，用于按 key 批量解析菜单名与配置文案（ADR 0013）。
     *
     * @param anonymous 未登录场景必须传 true，只解析可匿名公开的资源
     */
    public LocalizedText resolver(String locale, boolean anonymous) {
        return new LocalizedText(catalog(locale, anonymous).messages());
    }

    /** key 未命中时返回调用方原文，避免把内部 key 暴露给用户。 */
    public List<I18nLocaleView> locales(String displayLocale) {
        return catalogService.locales(displayLocale);
    }

    /** 用户偏好只能写入已经通过资源、菜单和字典覆盖门禁的语言。 */
    public boolean selectableLocale(String locale) {
        return catalogService.selectableLocale(locale);
    }

    public byte[] exportTranslations(String locale) {
        return workbookService.exportTranslations(locale);
    }

    @Transactional
    public TranslationImportResult importTranslations(
            String locale, byte[] bytes, KaiwuContext actor, RequestMetadata metadata) {
        return workbookService.importTranslations(locale, bytes, actor, metadata);
    }

    /** @param failures 最多回报前若干条，避免错误列表本身撑爆响应 */
    @Transactional
    public I18nMessageView save(I18nMessageSaveRequest request, KaiwuContext actor, RequestMetadata metadata) {
        return messageService.save(request, actor, metadata);
    }

    @Transactional
    public void delete(String id, long version, KaiwuContext actor, RequestMetadata metadata) {
        messageService.delete(id, version, actor, metadata);
    }
}
