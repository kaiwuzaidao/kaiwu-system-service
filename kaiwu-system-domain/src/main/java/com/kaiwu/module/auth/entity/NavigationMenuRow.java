package com.kaiwu.module.auth.entity;

/** 导航节点原始行；菜单名的译文由 Service 用统一入口解析，不在 SQL 里连表。 */
public class NavigationMenuRow {

    private String id;
    private String parentId;
    private String menuName;
    private String menuNameKey;
    private String menuType;
    private String routePath;
    private String icon;
    private Integer sortNo;

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getParentId() {
        return parentId;
    }

    public void setParentId(String parentId) {
        this.parentId = parentId;
    }

    public String getMenuName() {
        return menuName;
    }

    public void setMenuName(String menuName) {
        this.menuName = menuName;
    }

    public String getMenuNameKey() {
        return menuNameKey;
    }

    public void setMenuNameKey(String menuNameKey) {
        this.menuNameKey = menuNameKey;
    }

    public String getMenuType() {
        return menuType;
    }

    public void setMenuType(String menuType) {
        this.menuType = menuType;
    }

    public String getRoutePath() {
        return routePath;
    }

    public void setRoutePath(String routePath) {
        this.routePath = routePath;
    }

    public String getIcon() {
        return icon;
    }

    public void setIcon(String icon) {
        this.icon = icon;
    }

    public Integer getSortNo() {
        return sortNo;
    }

    public void setSortNo(Integer sortNo) {
        this.sortNo = sortNo;
    }
}
