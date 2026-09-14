package com.kaiwu.module.search;

import com.kaiwu.common.Result;
import com.kaiwu.module.search.vo.SearchItemView;
import com.kaiwu.starter.StarterContext;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/search")
public class GlobalSearchController {

    private final GlobalSearchService service;

    public GlobalSearchController(GlobalSearchService service) {
        this.service = service;
    }

    @GetMapping
    public Result<List<SearchItemView>> search(@RequestParam String q) {
        return Result.ok(service.search(q, StarterContext.require()));
    }
}
