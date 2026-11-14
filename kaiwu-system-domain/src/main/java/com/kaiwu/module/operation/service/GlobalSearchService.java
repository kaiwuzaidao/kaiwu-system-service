package com.kaiwu.module.operation.service;

import com.kaiwu.module.search.vo.SearchItemView;
import com.kaiwu.starter.KaiwuContext;
import java.util.List;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface GlobalSearchService {

    List<SearchItemView> search(String rawQuery, KaiwuContext actor);
}
