package com.kaiwu.module.configuration.controller;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

import com.kaiwu.module.configuration.service.MetadataService;
import org.junit.jupiter.api.Test;

class UiPreferencesAccessTest {
    @Test
    void unauthenticatedCallCannotReadPreferences() {
        MetadataService service = mock(MetadataService.class);
        MetadataController controller = new MetadataController(service);
        assertThatThrownBy(controller::platformUiPreferences).isInstanceOf(IllegalStateException.class);
        verifyNoInteractions(service);
    }
}
