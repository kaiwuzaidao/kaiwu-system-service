package com.kaiwu.module.metadata;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Base64;
import org.junit.jupiter.api.Test;

class ConfigEncryptionServiceTest {

    @Test
    void encryptsWithRandomIvAndDecryptsWithoutLeakingPlaintext() {
        String key = Base64.getEncoder().encodeToString(new byte[32]);
        ConfigEncryptionService service = new ConfigEncryptionService(key);

        String first = service.encrypt("secret-value");
        String second = service.encrypt("secret-value");

        assertThat(first).startsWith("v1:").doesNotContain("secret-value").isNotEqualTo(second);
        assertThat(service.decrypt(first)).isEqualTo("secret-value");
        assertThat(service.decrypt(null)).isNull();
    }
}
