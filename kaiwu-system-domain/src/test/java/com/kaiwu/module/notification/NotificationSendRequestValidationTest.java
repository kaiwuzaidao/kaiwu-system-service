package com.kaiwu.module.notification;

import static org.assertj.core.api.Assertions.assertThat;

import com.kaiwu.module.notification.dto.NotificationSendRequest;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import org.junit.jupiter.api.Test;

class NotificationSendRequestValidationTest {

    private final Validator validator =
            Validation.buildDefaultValidatorFactory().getValidator();

    @Test
    void acceptsOnlyInternalNotificationLinks() {
        assertThat(violations("/deliveries?task=123")).isZero();
        assertThat(violations("//evil.example/path")).isPositive();
        assertThat(violations("/\\evil.example/path")).isPositive();
        assertThat(violations("/%5cevil.example/path")).isPositive();
        assertThat(violations("/%252fevil.example/path")).isPositive();
        assertThat(violations("https://evil.example/path")).isPositive();
    }

    private int violations(String linkUrl) {
        NotificationSendRequest request = new NotificationSendRequest("demo", "1", "PROJECT", "标题", "正文", linkUrl);
        return validator.validate(request).size();
    }
}
