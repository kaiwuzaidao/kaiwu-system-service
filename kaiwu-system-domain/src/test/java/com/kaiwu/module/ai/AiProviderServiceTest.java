package com.kaiwu.module.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.module.ai.AiProviderRepository.ProviderRow;
import com.kaiwu.module.ai.dto.AiProviderSaveRequest;
import com.kaiwu.module.metadata.ConfigEncryptionService;
import java.math.BigDecimal;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class AiProviderServiceTest {

    @Test
    void appliesDefaultsNormalizesUrlAndEncryptsTrimmedSecret() {
        AiProviderRepository repository = mock(AiProviderRepository.class);
        ConfigEncryptionService encryption = mock(ConfigEncryptionService.class);
        when(repository.current()).thenReturn(Optional.empty());
        when(encryption.encrypt("secret")).thenReturn("ciphertext");
        AiProviderService service = new AiProviderService(repository, encryption);

        service.save(new AiProviderSaveRequest(
                " provider ", "https://model.example/v1///", " secret ", false, " model ", null, null, null));

        ArgumentCaptor<ProviderRow> captor = ArgumentCaptor.forClass(ProviderRow.class);
        verify(repository).save(captor.capture());
        ProviderRow saved = captor.getValue();
        assertThat(saved.providerName()).isEqualTo("provider");
        assertThat(saved.baseUrl()).isEqualTo("https://model.example/v1");
        assertThat(saved.apiKeyCiphertext()).isEqualTo("ciphertext");
        assertThat(saved.model()).isEqualTo("model");
        assertThat(saved.temperature()).isEqualByComparingTo(new BigDecimal("0.2"));
        assertThat(saved.timeoutSeconds()).isEqualTo(60);
        assertThat(saved.enabled()).isTrue();
    }

    @Test
    void clearSecretTakesPrecedenceOverReplacement() {
        AiProviderRepository repository = mock(AiProviderRepository.class);
        ConfigEncryptionService encryption = mock(ConfigEncryptionService.class);
        when(repository.current())
                .thenReturn(Optional.of(new ProviderRow(
                        "old",
                        "https://old.example/v1",
                        "old-cipher",
                        "old-model",
                        new BigDecimal("0.1"),
                        30,
                        true,
                        "SUCCESS",
                        "ok",
                        null)));
        AiProviderService service = new AiProviderService(repository, encryption);

        service.save(new AiProviderSaveRequest(
                "new", "https://new.example/v1", "replacement", true, "new-model", new BigDecimal("0.4"), 45, false));

        ArgumentCaptor<ProviderRow> captor = ArgumentCaptor.forClass(ProviderRow.class);
        verify(repository).save(captor.capture());
        assertThat(captor.getValue().apiKeyCiphertext()).isNull();
        assertThat(captor.getValue().lastTestStatus()).isEqualTo("SUCCESS");
        assertThat(captor.getValue().enabled()).isFalse();
    }
}
