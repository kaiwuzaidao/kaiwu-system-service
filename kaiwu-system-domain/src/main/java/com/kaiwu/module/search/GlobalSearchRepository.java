package com.kaiwu.module.search;

import com.kaiwu.module.search.mapper.GlobalSearchMapper;
import com.kaiwu.module.search.vo.SearchItemView;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Repository;

@Repository
public class GlobalSearchRepository {

    private final GlobalSearchMapper mapper;

    public GlobalSearchRepository(GlobalSearchMapper mapper) {
        this.mapper = mapper;
    }

    /** 搜项目；{@code listAll} 为 false 时只返回该用户为 ACTIVE 成员的项目。 */
    public List<SearchItemView> searchProjects(String query, String userId, boolean listAll) {
        return mapper.searchProjects(like(query), userId, listAll).stream()
                .map(row -> new SearchItemView(
                        "PROJECT", text(row, "id"), text(row, "projectName"), text(row, "projectCode"), "/projects"))
                .toList();
    }

    /** 搜用户；同时匹配用户名、显示名与邮箱。 */
    public List<SearchItemView> searchUsers(String query) {
        return mapper.searchUsers(like(query)).stream()
                .map(row -> new SearchItemView(
                        "USER",
                        text(row, "id"),
                        text(row, "displayName"),
                        "@" + text(row, "username") + " · " + text(row, "status"),
                        "/users"))
                .toList();
    }

    /** 搜生成任务；{@code listAll} 为 false 时限定为本人发起或所属项目的任务。 */
    public List<SearchItemView> searchDeliveries(String query, String userId, boolean listAll) {
        return mapper.searchDeliveries(like(query), userId, listAll).stream()
                .map(row -> new SearchItemView(
                        "DELIVERY",
                        text(row, "taskNo"),
                        text(row, "projectName"),
                        text(row, "projectCode") + " · " + text(row, "generationStatus"),
                        "/project-factory"))
                .toList();
    }

    private static String like(String query) {
        return "%" + query + "%";
    }

    private static String text(Map<String, Object> row, String column) {
        Object value = row.get(column);
        return value == null ? null : String.valueOf(value);
    }
}
