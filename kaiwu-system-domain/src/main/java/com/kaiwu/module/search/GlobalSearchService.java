package com.kaiwu.module.search;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.search.vo.SearchItemView;
import com.kaiwu.starter.KaiwuContext;
import java.util.ArrayList;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class GlobalSearchService {

    private final GlobalSearchRepository repository;

    public GlobalSearchService(GlobalSearchRepository repository) {
        this.repository = repository;
    }

    /**
     * 全局搜索：项目、用户与生成任务。
     *
     * <p>关键字少于 2 个字符直接返回空，避免一次单字符查询扫全表。
     * 可见范围按调用者的权限收窄，不是管理员就只看得到自己参与的项目。</p>
     */
    public List<SearchItemView> search(String rawQuery, KaiwuContext actor) {
        String query = rawQuery == null ? "" : rawQuery.trim();
        if (query.length() < 2 || query.length() > 100) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "搜索关键词长度必须为 2-100 个字符", "api.common.badRequest");
        }
        boolean listAllProjects = actor.permissions().contains("system:project:list");
        List<SearchItemView> results = new ArrayList<>();
        results.addAll(repository.searchProjects(query, actor.userId(), listAllProjects));
        results.addAll(repository.searchDeliveries(query, actor.userId(), listAllProjects));
        if (actor.permissions().contains("system:user:list")) {
            results.addAll(repository.searchUsers(query));
        }
        return results;
    }
}
