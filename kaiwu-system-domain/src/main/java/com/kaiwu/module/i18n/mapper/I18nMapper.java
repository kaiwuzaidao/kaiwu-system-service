package com.kaiwu.module.i18n.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.i18n.entity.I18nMessageEntity;
import com.kaiwu.module.i18n.entity.LocaleJoinRow;
import com.kaiwu.module.i18n.entity.TranslationExportJoinRow;
import java.util.List;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/**
 * 国际化资源 Mapper。
 *
 * <p>单表读取走 {@link BaseMapper}；下面的注解 SQL 分三类，都是条件构造器表达不了的：
 * 带 {@code version} 守卫的乐观锁更新、MySQL 的 JSON 函数（{@code JSON_SET} /
 * {@code JSON_EXTRACT}）、以及多表 {@code UPDATE ... JOIN}。</p>
 */
@Mapper
public interface I18nMapper extends BaseMapper<I18nMessageEntity> {

    /**
     * 带乐观锁的更新。
     *
     * <p>{@code WHERE id = ? AND version = ?} 影响 0 行即表示他人已改过，由上层报冲突。
     * 换成实体更新会丢掉这个守卫，两个管理员同时编辑同一条资源时后写的静默覆盖先写的。</p>
     */
    @Update(
            """
            UPDATE sys_i18n_message
            SET message_key = #{messageKey}, default_text = #{defaultText},
                translations_json = #{translationsJson}, module_code = #{moduleCode},
                public_visible = #{publicVisible}, required_resource = #{requiredResource},
                status = #{status}, description = #{description},
                version = version + 1, updated_at = CURRENT_TIMESTAMP
            WHERE id = #{id} AND version = #{expectedVersion}
            """)
    int updateWithVersion(
            @Param("id") long id,
            @Param("messageKey") String messageKey,
            @Param("defaultText") String defaultText,
            @Param("translationsJson") String translationsJson,
            @Param("moduleCode") String moduleCode,
            @Param("publicVisible") boolean publicVisible,
            @Param("requiredResource") boolean requiredResource,
            @Param("status") String status,
            @Param("description") String description,
            @Param("expectedVersion") long expectedVersion);

    @Delete("DELETE FROM sys_i18n_message WHERE id = #{id} AND version = #{expectedVersion}")
    int deleteWithVersion(@Param("id") long id, @Param("expectedVersion") long expectedVersion);

    @Select("SELECT revision FROM sys_i18n_catalog_revision WHERE catalog_code = 'platform'")
    Long revision();

    @Update(
            """
            UPDATE sys_i18n_catalog_revision
            SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
            WHERE catalog_code = 'platform'
            """)
    int bumpRevision();

    @Select(
            """
            SELECT item.item_value
            FROM sys_dict_type type
            JOIN sys_dict_item item ON item.dict_type_id = type.id
            WHERE type.scope_id = 0 AND type.dict_code = 'platform.locale'
              AND type.status = 'ENABLED' AND item.status = 'ENABLED'
            ORDER BY item.sort_no, item.id
            """)
    List<String> enabledLocales();

    @Select(
            """
            SELECT item.item_value, item.item_label, item.label_i18n_key,
                   item.extra_json, item.default_item
            FROM sys_dict_type type
            JOIN sys_dict_item item ON item.dict_type_id = type.id
            WHERE type.scope_id = 0 AND type.dict_code = 'platform.locale'
              AND type.status = 'ENABLED' AND item.status = 'ENABLED'
            ORDER BY item.sort_no, item.id
            """)
    List<LocaleJoinRow> locales();

    @Select(
            """
            SELECT COUNT(*) FROM sys_i18n_message
            WHERE status = 'ENABLED' AND required_resource = 1
              AND (translations_json IS NULL
                   OR NULLIF(JSON_UNQUOTE(JSON_EXTRACT(
                        translations_json, CONCAT('$."', #{locale}, '"'))), '') IS NULL)
            """)
    Long missingRequiredResources(@Param("locale") String locale);

    /**
     * 没有译文来源的内置菜单数。
     *
     * <p>ADR 0015 后菜单译文只存在资源目录里：没有引用资源就是没有译文来源。
     * BUTTON 同样会在权限中心显示，不能因其不出现在侧边栏而漏掉。已引用且启用的资源
     * 仍由资源覆盖率统计，避免将同一语言缺口重复计数。</p>
     */
    @Select(
            """
            SELECT COUNT(*)
            FROM sys_project_menu menu
            JOIN sys_project project ON project.id = menu.project_id
            LEFT JOIN sys_i18n_message resource
              ON resource.message_key = menu.menu_name_key
             AND resource.status = 'ENABLED'
            WHERE project.project_code = 'system'
              AND menu.status = 'ACTIVE' AND menu.visible = 1
              AND menu.menu_type IN ('DIRECTORY', 'MENU', 'BUTTON')
              AND (menu.menu_name_key IS NULL OR resource.message_key IS NULL)
            """)
    Long missingMenus();

    @Select(
            """
            SELECT COUNT(*)
            FROM sys_dict_type type
            JOIN sys_dict_item item ON item.dict_type_id = type.id
            LEFT JOIN sys_i18n_message resource
              ON resource.message_key = item.label_i18n_key
             AND resource.status = 'ENABLED'
            WHERE type.scope_id = 0 AND type.status = 'ENABLED'
              AND item.status = 'ENABLED' AND type.dict_code <> 'platform.locale'
              AND (item.label_i18n_key IS NULL
                   OR NULLIF(JSON_UNQUOTE(JSON_EXTRACT(
                        resource.translations_json, CONCAT('$."', #{locale}, '"'))), '') IS NULL)
            """)
    Long missingDictionaryItems(@Param("locale") String locale);

    // ---- 译文批量导出/导入 ----
    // 导出与覆盖率校验必须用同一套筛选条件，否则会出现「导出表填满了，
    // 语言仍显示未开放」的死循环。

    /** 需要翻译的平台资源：与 missingRequiredResources 同条件，含已有译文以便复核。 */
    @Select(
            """
            SELECT message_key AS export_key, default_text AS default_text,
                   description AS note,
                   NULLIF(JSON_UNQUOTE(JSON_EXTRACT(
                       translations_json, CONCAT('$."', #{locale}, '"'))), '') AS translation
            FROM sys_i18n_message
            WHERE status = 'ENABLED' AND required_resource = 1
            ORDER BY module_code, message_key
            """)
    List<TranslationExportJoinRow> exportResources(@Param("locale") String locale);

    /**
     * 尚未引用有效资源的内置菜单：与 missingMenus 同条件。
     *
     * <p>ADR 0015 后菜单译文只存在资源目录，本 sheet 只剩「还没接入资源的菜单」，
     * 正常情况下为空；留着是为了在有人手工建了无 key 菜单时仍能被发现。</p>
     */
    @Select(
            """
            SELECT COALESCE(menu.permission_code, menu.route_path, CAST(menu.id AS CHAR)) AS export_key,
                   menu.menu_name AS default_text,
                   NULL AS note, NULL AS translation
            FROM sys_project_menu menu
            JOIN sys_project project ON project.id = menu.project_id
            LEFT JOIN sys_i18n_message resource
              ON resource.message_key = menu.menu_name_key
             AND resource.status = 'ENABLED'
            WHERE project.project_code = 'system'
              AND menu.status = 'ACTIVE' AND menu.visible = 1
              AND menu.menu_type IN ('DIRECTORY', 'MENU', 'BUTTON')
              AND (menu.menu_name_key IS NULL OR resource.message_key IS NULL)
            ORDER BY menu.sort_no, menu.id
            """)
    List<TranslationExportJoinRow> exportMenus();

    /**
     * 需要翻译的全局字典项：译文来自引用资源，而不是 ADR 0015 已退役的内联列。
     * key 用 dictCode:itemValue，保留无引用项以便导入时明确报告并促使修正。
     */
    @Select(
            """
            SELECT CONCAT(type.dict_code, ':', item.item_value) AS export_key,
                   COALESCE(resource.default_text, item.item_label) AS default_text,
                   type.dict_name AS note,
                   NULLIF(JSON_UNQUOTE(JSON_EXTRACT(
                       resource.translations_json, CONCAT('$."', #{locale}, '"'))), '') AS translation
            FROM sys_dict_type type
            JOIN sys_dict_item item ON item.dict_type_id = type.id
            LEFT JOIN sys_i18n_message resource
              ON resource.message_key = item.label_i18n_key
             AND resource.status = 'ENABLED'
            WHERE type.scope_id = 0 AND type.status = 'ENABLED'
              AND item.status = 'ENABLED' AND type.dict_code <> 'platform.locale'
            ORDER BY type.dict_code, item.sort_no
            """)
    List<TranslationExportJoinRow> exportDictionaryItems(@Param("locale") String locale);

    /**
     * 写入单条译文。
     *
     * <p>用 {@code JSON_SET} 只改目标语言那一个键，不整体替换 JSON——整体替换会把其它
     * 语言的译文一起冲掉。返回受影响行数以便区分「key 不存在」与「已写入」。</p>
     */
    @Update(
            """
            UPDATE sys_i18n_message
            SET translations_json = JSON_SET(
                    COALESCE(translations_json, JSON_OBJECT()),
                    CONCAT('$."', #{locale}, '"'), #{translation}),
                version = version + 1, updated_at = CURRENT_TIMESTAMP
            WHERE message_key = #{messageKey} AND status = 'ENABLED'
            """)
    int upsertResourceTranslation(
            @Param("messageKey") String messageKey,
            @Param("locale") String locale,
            @Param("translation") String translation);

    /**
     * 导入菜单译文：写进该菜单**引用的资源**，而不是已退役的内联列（ADR 0015）。
     *
     * <p>菜单没有引用资源时返回 0，由上层汇总成一条可修正的失败——静默丢弃译文
     * 比报错难发现得多。</p>
     */
    @Update(
            """
            UPDATE sys_i18n_message message
            JOIN sys_project_menu menu ON menu.menu_name_key = message.message_key
            JOIN sys_project project ON project.id = menu.project_id
            SET message.translations_json = JSON_SET(
                    COALESCE(message.translations_json, JSON_OBJECT()),
                    CONCAT('$."', #{locale}, '"'), #{translation}),
                message.version = message.version + 1,
                message.updated_at = CURRENT_TIMESTAMP
            WHERE project.project_code = 'system' AND menu.route_path = #{routePath}
            """)
    int upsertMenuTranslation(
            @Param("routePath") String routePath,
            @Param("locale") String locale,
            @Param("translation") String translation);

    @Update(
            """
            UPDATE sys_i18n_message resource
            JOIN sys_dict_item item ON item.label_i18n_key = resource.message_key
            JOIN sys_dict_type type ON type.id = item.dict_type_id
            SET resource.translations_json = JSON_SET(
                    COALESCE(resource.translations_json, JSON_OBJECT()),
                    CONCAT('$."', #{locale}, '"'), #{translation}),
                resource.version = resource.version + 1,
                resource.updated_at = CURRENT_TIMESTAMP
            WHERE type.scope_id = 0 AND type.dict_code = #{dictCode}
              AND item.item_value = #{itemValue}
              AND resource.status = 'ENABLED'
            """)
    int upsertDictionaryTranslation(
            @Param("dictCode") String dictCode,
            @Param("itemValue") String itemValue,
            @Param("locale") String locale,
            @Param("translation") String translation);
}
