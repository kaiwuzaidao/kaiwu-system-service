package com.kaiwu.module.i18n;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.kaiwu.module.i18n.vo.I18nCatalogView;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class I18nControllerTest {

    @Test
    void publicCatalogReturnsEtagAndSupportsConditionalRequest() {
        I18nService service = mock(I18nService.class);
        I18nCatalogView catalog = new I18nCatalogView("en-US", 7L, Map.of("login.title", "Sign in"));
        when(service.catalog("en-US", true)).thenReturn(catalog);
        I18nController controller = new I18nController(service);

        var first = controller.publicCatalog("en-US", null, null);
        var unchanged = controller.publicCatalog("en-US", 7L, first.getHeaders().getETag());

        assertThat(first.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(first.getHeaders().getETag()).isEqualTo("\"i18n-en-US-7\"");
        assertThat(unchanged.getStatusCode()).isEqualTo(HttpStatus.NOT_MODIFIED);
        assertThat(unchanged.getBody()).isNull();
    }
}
