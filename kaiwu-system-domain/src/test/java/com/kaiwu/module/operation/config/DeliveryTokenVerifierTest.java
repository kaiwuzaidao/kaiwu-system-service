package com.kaiwu.module.operation.config;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.kaiwu.common.ApiException;
import org.junit.jupiter.api.Test;

/**
 * 业务服务投递凭据校验：未配置拒绝、缺失或不匹配拒绝、匹配放行。站内信与待办的投递端点共用这一份实现。
 */
class DeliveryTokenVerifierTest {

    /** 按给定的已配置凭据构造校验器。 */
    private DeliveryTokenVerifier verifier(String configured) {
        NotificationProperties properties = new NotificationProperties();
        properties.setDeliveryToken(configured);
        return new DeliveryTokenVerifier(properties);
    }

    /** 凭据未配置时一律 503，不提供任何默认放行，连「正确」的空凭据也不行。 */
    @Test
    void rejectsEverythingWhenNoTokenConfigured() {
        assertThatThrownBy(() -> verifier(null).require("anything"))
                .isInstanceOfSatisfying(ApiException.class, error -> org.assertj.core.api.Assertions.assertThat(
                                error.getStatus().value())
                        .isEqualTo(503));
        assertThatThrownBy(() -> verifier(" ").require(" "))
                .isInstanceOfSatisfying(ApiException.class, error -> org.assertj.core.api.Assertions.assertThat(
                                error.getStatus().value())
                        .isEqualTo(503));
    }

    /** 请求没带凭据或凭据不一致时 401。 */
    @Test
    void rejectsMissingOrWrongToken() {
        for (String presented : new String[] {null, "", "wrong", "secret "}) {
            assertThatThrownBy(() -> verifier("secret").require(presented))
                    .isInstanceOfSatisfying(ApiException.class, error -> org.assertj.core.api.Assertions.assertThat(
                                    error.getStatus().value())
                            .isEqualTo(401));
        }
    }

    /** 凭据一致才放行。 */
    @Test
    void acceptsMatchingToken() {
        assertThatCode(() -> verifier("secret").require("secret")).doesNotThrowAnyException();
    }
}
