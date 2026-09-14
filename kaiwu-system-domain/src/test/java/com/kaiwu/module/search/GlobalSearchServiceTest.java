package com.kaiwu.module.search;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.module.search.vo.SearchItemView;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;

class GlobalSearchServiceTest {

    @Test
    void userResultsAreOmittedWithoutUserListPermission() {
        GlobalSearchRepository repository = mock(GlobalSearchRepository.class);
        GlobalSearchService service = new GlobalSearchService(repository);
        KaiwuContext actor = context(Set.of("system:platform:read"));
        when(repository.searchProjects("alpha", "1", false))
                .thenReturn(List.of(new SearchItemView("PROJECT", "10", "Alpha", "alpha", "/projects")));
        when(repository.searchDeliveries("alpha", "1", false)).thenReturn(List.of());

        assertThat(service.search(" alpha ", actor))
                .extracting(SearchItemView::type)
                .containsExactly("PROJECT");
        verify(repository, never()).searchUsers("alpha");
    }

    private static KaiwuContext context(Set<String> permissions) {
        return new KaiwuContext(
                "1",
                "s1",
                null,
                null,
                permissions,
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "c1");
    }
}
