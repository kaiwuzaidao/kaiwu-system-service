package com.kaiwu.module.connector.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

import com.kaiwu.module.configuration.service.ConfigEncryptionService;
import com.kaiwu.module.connector.dto.AiModelRoutes;
import com.kaiwu.module.connector.dto.AiModelSaveRequest;
import com.kaiwu.module.connector.entity.AiModelRouteEntity;
import com.kaiwu.module.connector.repository.AiModelRouteRepository;
import com.kaiwu.module.connector.repository.AiProviderRepository;
import com.kaiwu.module.connector.repository.AiProviderRepository.ProviderRow;
import com.kaiwu.module.connector.service.impl.AiProviderServiceImpl;
import java.math.BigDecimal;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** 验证用途路由与模型密钥的安全边界。 */
class AiModelConfigServiceTest {
    private final AiProviderRepository repository = mock(AiProviderRepository.class);
    private final AiModelRouteRepository routes = mock(AiModelRouteRepository.class);
    private final ConfigEncryptionService encryption = mock(ConfigEncryptionService.class);
    private final AiProviderService service = new AiProviderServiceImpl(repository, encryption, routes);

    /** 默认和显式用途绑定分别解析且缺失不回退。 */
    @Test
    void defaultAndExplicitBindingsResolveIndependently() {
        AiModelRouteEntity binding = new AiModelRouteEntity();
        binding.setAnswerModelId(22L);
        when(routes.current()).thenReturn(binding);
        when(repository.find(1L)).thenReturn(Optional.of(row("default", "cipher-one")));
        when(repository.find(22L)).thenReturn(Optional.of(row("answer", "cipher-two")));
        when(encryption.decrypt("cipher-one")).thenReturn("key-one");
        when(encryption.decrypt("cipher-two")).thenReturn("key-two");
        assertThat(service.effectiveFor("PLAN")).hasValueSatisfying(c -> {
            assertThat(c.modelId()).isEqualTo("1");
            assertThat(c.config().model()).isEqualTo("default");
        });
        assertThat(service.effectiveFor("ANSWER")).hasValueSatisfying(c -> {
            assertThat(c.modelId()).isEqualTo("22");
            assertThat(c.config().apiKey()).isEqualTo("key-two");
        });
        when(repository.find(22L)).thenReturn(Optional.empty());
        assertThat(service.effectiveFor("ANSWER")).isEmpty();
    }

    /** 无效目标不得部分写入用途绑定。 */
    @Test
    void missingTargetCannotPartiallyChangeRoutes() {
        when(repository.find(12L)).thenReturn(Optional.of(row("plan", "cipher")));
        when(repository.find(99L)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.saveRoutes(new AiModelRoutes("12", "99")))
                .isInstanceOf(RuntimeException.class);
        verify(routes, never()).save(any(), any());
    }

    /** 编辑留空密钥时沿用密文且接口不返回密钥。 */
    @Test
    void editingWithBlankSecretPreservesCiphertextAndDoesNotReturnIt() {
        when(repository.find(12L)).thenReturn(Optional.of(row("old", "cipher")));
        var result = service.saveModel(new AiModelSaveRequest(
                "12", "provider", "https://model.example/v1", "", false, "new", BigDecimal.valueOf(0.2), 60));
        ArgumentCaptor<ProviderRow> captured = ArgumentCaptor.forClass(ProviderRow.class);
        verify(repository).save(eq(12L), captured.capture());
        assertThat(captured.getValue().apiKeyCiphertext()).isEqualTo("cipher");
        assertThat(result.apiKeyConfigured()).isTrue();
        assertThat(result.toString()).doesNotContain("cipher");
    }

    /** 编辑后立即返回待重新测试状态，不复用旧连接结果。 */
    @Test
    void editingClearsPriorTestStatusInResponse() {
        when(repository.find(12L))
                .thenReturn(Optional.of(new ProviderRow(
                        "provider",
                        "https://model.example/v1",
                        "cipher",
                        "old",
                        BigDecimal.valueOf(0.2),
                        60,
                        true,
                        "SUCCESS",
                        "old result",
                        null)));
        var result = service.saveModel(new AiModelSaveRequest(
                "12", "provider", "https://model.example/v1", "", false, "new", BigDecimal.valueOf(0.2), 60));
        assertThat(result.lastTestStatus()).isNull();
        assertThat(result.lastTestMessage()).isNull();
        ArgumentCaptor<ProviderRow> captured = ArgumentCaptor.forClass(ProviderRow.class);
        verify(repository).save(eq(12L), captured.capture());
        assertThat(captured.getValue().lastTestStatus()).isNull();
    }

    /** 配置和密钥变更后旧测试携带旧修订号，不能覆盖新状态。 */
    @Test
    void testResultUsesOriginalConfigurationRevision() {
        when(repository.findForTest(12L))
                .thenReturn(Optional.of(new AiProviderRepository.TestRow(row("old", "old-cipher"), 9L)));
        when(encryption.decrypt("old-cipher")).thenReturn("old-secret");
        var snapshot = service.prepareModelTest("12").orElseThrow();
        assertThat(snapshot.revision()).isEqualTo(9L);
        var testedAt = java.time.LocalDateTime.of(2026, 1, 1, 0, 0);
        when(repository.recordTestIfRevision(12L, 9L, true, "ok", testedAt)).thenReturn(false);
        assertThat(service.recordModelTestIfRevision("12", snapshot.revision(), true, "ok", testedAt))
                .isFalse();
        verify(repository).recordTestIfRevision(12L, 9L, true, "ok", testedAt);
    }

    /** 修改地址时必须显式处理原密钥。 */
    @Test
    void changingEndpointCannotCarryExistingSecret() {
        when(repository.find(12L)).thenReturn(Optional.of(row("old", "cipher")));
        assertThatThrownBy(() -> service.saveModel(new AiModelSaveRequest(
                        "12", "provider", "https://new.example/v1", "", false, "new", BigDecimal.valueOf(0.2), 60)))
                .isInstanceOf(RuntimeException.class);
        verify(repository, never()).save(eq(12L), any());
        service.saveModel(new AiModelSaveRequest(
                "12", "provider", "https://new.example/v1", "", true, "new", BigDecimal.valueOf(0.2), 60));
        ArgumentCaptor<ProviderRow> captured = ArgumentCaptor.forClass(ProviderRow.class);
        verify(repository).save(eq(12L), captured.capture());
        assertThat(captured.getValue().apiKeyCiphertext()).isNull();
    }

    /** 生成仅供测试的模型配置。 */
    private static ProviderRow row(String model, String cipher) {
        return new ProviderRow(
                "provider",
                "https://model.example/v1",
                cipher,
                model,
                BigDecimal.valueOf(0.2),
                60,
                true,
                null,
                null,
                null);
    }
}
