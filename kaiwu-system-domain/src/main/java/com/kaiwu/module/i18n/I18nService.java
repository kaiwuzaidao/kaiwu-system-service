package com.kaiwu.module.i18n;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.i18n.dto.I18nMessageSaveRequest;
import com.kaiwu.module.i18n.vo.I18nCatalogView;
import com.kaiwu.module.i18n.vo.I18nLocaleView;
import com.kaiwu.module.i18n.vo.I18nMessageView;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * 国际化应用服务 façade。
 *
 * <p>对 Controller 和其它领域保持稳定入口；目录查询、资源规则和工作簿处理分别委托给
 * 聚焦的协作者。事务边界留在 façade，确保导入和资源变更中的数据、版本与审计原子提交。</p>
 */
@Service
public class I18nService {

    private final I18nCatalogService catalogService;
    private final I18nMessageService messageService;
    private final I18nWorkbookService workbookService;

    public I18nService(
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

    /**
     * 取一次目录快照，用于按 key 批量解析菜单名与配置文案（ADR 0013）。
     *
     * @param anonymous 未登录场景必须传 true，只解析可匿名公开的资源
     */
    public LocalizedText resolver(String locale, boolean anonymous) {
        return new LocalizedText(catalog(locale, anonymous).messages());
    }

    /** key 未命中时返回调用方原文，避免把内部 key 暴露给用户。 */
    public record LocalizedText(Map<String, String> messages) {

        public LocalizedText {
            messages = messages == null ? Map.of() : Map.copyOf(messages);
        }

        public String of(String key, String fallback) {
            if (!StringUtils.hasText(key)) return fallback;
            String text = messages.get(key);
            return StringUtils.hasText(text) ? text : fallback;
        }
    }

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
    public record TranslationImportResult(int applied, List<String> failures) {}

    @Transactional
    public I18nMessageView save(I18nMessageSaveRequest request, KaiwuContext actor, RequestMetadata metadata) {
        return messageService.save(request, actor, metadata);
    }

    @Transactional
    public void delete(String id, long version, KaiwuContext actor, RequestMetadata metadata) {
        messageService.delete(id, version, actor, metadata);
    }
}
