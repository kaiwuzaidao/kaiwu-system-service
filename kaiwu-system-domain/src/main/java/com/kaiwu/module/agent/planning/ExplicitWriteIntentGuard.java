package com.kaiwu.module.agent.planning;

import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.agent.protocol.Capability;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/** 对高置信度的写任务在规划前核对实时可见目录，不向模型透露无权能力。 */
public final class ExplicitWriteIntentGuard {
    private ExplicitWriteIntentGuard() {}

    public static boolean denied(String question, List<Capability> visible) {
        if (question == null || question.isBlank()) return false;
        Set<String> codes = visible.stream().map(Capability::code).collect(Collectors.toSet());
        if (projectCreate(question) && !codes.contains(CapabilityCatalog.PROJECT_CREATE)) return true;
        if (projectRoleCreate(question) && !codes.contains(CapabilityCatalog.PROJECT_ROLE_CREATE)) return true;
        if (projectRoleUpdate(question) && !codes.contains(CapabilityCatalog.PROJECT_ROLE_UPDATE)) return true;
        if (projectRoleDelete(question) && !codes.contains(CapabilityCatalog.PROJECT_ROLE_DELETE)) return true;
        if (projectRoleStatusUpdate(question) && !codes.contains(CapabilityCatalog.PROJECT_ROLE_STATUS_UPDATE))
            return true;
        if (projectRoleMenuGrant(question) && !codes.contains(CapabilityCatalog.PROJECT_ROLE_MENU_GRANT)) return true;
        if (projectMenuStatusUpdate(question) && !codes.contains(CapabilityCatalog.PROJECT_MENU_STATUS_UPDATE))
            return true;
        if (projectMenuDelete(question) && !codes.contains(CapabilityCatalog.PROJECT_MENU_DELETE)) return true;
        if (projectMenuCreate(question) && !codes.contains(CapabilityCatalog.PROJECT_MENU_CREATE)) return true;
        if (projectMenuUpdate(question) && !codes.contains(CapabilityCatalog.PROJECT_MENU_UPDATE)) return true;
        if (projectMemberSave(question) && !codes.contains(CapabilityCatalog.PROJECT_MEMBER_SAVE)) return true;
        if (projectMemberDelete(question) && !codes.contains(CapabilityCatalog.PROJECT_MEMBER_DELETE)) return true;
        if (dictTypeCreate(question) && !codes.contains(CapabilityCatalog.DICT_TYPE_CREATE)) return true;
        if (dictTypeDelete(question) && !codes.contains(CapabilityCatalog.DICT_TYPE_DELETE)) return true;
        if (dictItemCreate(question) && !codes.contains(CapabilityCatalog.DICT_ITEM_CREATE)) return true;
        if (departmentCreate(question) && !codes.contains(CapabilityCatalog.DEPARTMENT_CREATE)) return true;
        if (departmentDelete(question) && !codes.contains(CapabilityCatalog.DEPARTMENT_DELETE)) return true;
        if (userDepartmentAssign(question) && !codes.contains(CapabilityCatalog.USER_DEPARTMENT_ASSIGN)) return true;
        if (userCreate(question) && !codes.contains(CapabilityCatalog.USER_CREATE)) return true;
        return userStatusUpdate(question) && !codes.contains(CapabilityCatalog.USER_STATUS_UPDATE);
    }

    private static boolean projectCreate(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否") || text.contains("项目角色")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:创建|新建).{0,12}项目.*");
    }

    private static boolean projectRoleCreate(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:创建|新建|添加).{0,12}项目角色.*");
    }

    private static boolean projectRoleUpdate(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:修改|编辑|重命名).{0,12}项目角色.*")
                || text.matches("^(?:请|帮我|麻烦)?(?:把|将).{0,20}项目角色.{0,20}(?:改名|修改名称|重命名).*");
    }

    private static boolean projectRoleDelete(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:删除|移除).{0,12}项目角色.*");
    }

    private static boolean projectRoleStatusUpdate(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:启用|停用|禁用).{0,12}项目角色.*");
    }

    private static boolean projectRoleMenuGrant(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:给|为|设置|修改|调整|分配|授予|清空|撤销).{0,20}项目角色.{0,20}(?:菜单|权限).*");
    }

    private static boolean projectMenuStatusUpdate(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:启用|停用|禁用).{0,12}项目菜单.*");
    }

    private static boolean projectMenuDelete(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:删除|移除).{0,12}项目菜单.*");
    }

    private static boolean projectMenuCreate(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:创建|新建|添加).{0,12}项目菜单.*");
    }

    private static boolean projectMenuUpdate(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:修改|编辑|重命名|调整).{0,12}项目菜单.*");
    }

    private static boolean projectMemberSave(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:添加|新增|设置|调整|修改|启用|停用).{0,20}项目成员.*")
                || text.matches("^(?:请|帮我|麻烦)?(?:给|为).{0,20}项目成员.{0,20}(?:角色|权限).*");
    }

    private static boolean projectMemberDelete(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:删除|移除).{0,20}项目成员.*");
    }

    private static boolean dictTypeDelete(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:删除|移除).{0,12}字典类型.*");
    }

    private static boolean dictTypeCreate(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否") || text.contains("字典项")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:创建|新建|添加).{0,12}字典(?:类型)?.*");
    }

    private static boolean userCreate(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:创建|新建|添加).{0,12}(?:平台)?用户.*");
    }

    private static boolean dictItemCreate(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:创建|新建|添加).{0,12}字典项.*");
    }

    private static boolean departmentCreate(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:创建|新建|添加).{0,12}部门.*");
    }

    private static boolean departmentDelete(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:删除|移除).{0,12}部门.*");
    }

    private static boolean userDepartmentAssign(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:设置|调整|分配|清空|移除).{0,20}(?:用户部门|部门归属|所属部门).*");
    }

    private static boolean userStatusUpdate(String text) {
        if (text.contains("如何") || text.contains("怎么") || text.contains("能否")) return false;
        return text.matches("^(?:请|帮我|麻烦)?(?:启用|停用|禁用).{0,20}用户.*")
                || text.matches("^(?:请|帮我|麻烦)?(?:把|将).{0,20}用户.{0,20}(?:启用|停用|禁用).*");
    }
}
