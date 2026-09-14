package com.kaiwu.module.i18n.vo;

/**
 * 语言目录及覆盖状态。
 *
 * @param locale 规范 BCP 47 locale
 * @param label 语言目录展示名
 * @param selectableConfigured 管理员是否允许开放选择
 * @param selectable 覆盖校验后是否真正可供用户选择
 * @param missingRequiredResources 缺失的必需固定文案数
 * @param missingMenus 缺失的导航菜单译文数
 * @param missingDictionaryItems 缺失的全局字典项译文数
 */
public record I18nLocaleView(
        String locale,
        String label,
        boolean selectableConfigured,
        boolean selectable,
        long missingRequiredResources,
        long missingMenus,
        long missingDictionaryItems) {}
