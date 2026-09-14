package com.kaiwu.common;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** 分页边界的行为：越界拒绝，不截断。 */
class PageBoundsTest {

    @Test
    void acceptsParametersInsideTheAllowedRange() {
        assertThatCode(() -> PageBounds.require(1, 1)).doesNotThrowAnyException();
        assertThatCode(() -> PageBounds.require(9_999, PageBounds.MAX_SIZE)).doesNotThrowAnyException();
        assertThatCode(() -> PageBounds.requireSize(PageBounds.MAX_SIZE)).doesNotThrowAnyException();
    }

    /**
     * 越界必须报 400 而不是悄悄改小。
     *
     * <p>截断会让调用方以为拿到了全量——少数据比报错更难被发现。</p>
     */
    @Test
    void rejectsOversizedPageInsteadOfTruncating() {
        assertThatThrownBy(() -> PageBounds.require(1, PageBounds.MAX_SIZE + 1))
                .isInstanceOfSatisfying(ApiException.class, exception -> {
                    assertThat(exception.getStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(exception.getMessageKey()).isEqualTo("api.pagination.invalid");
                });
        assertThatThrownBy(() -> PageBounds.requireSize(Long.MAX_VALUE)).isInstanceOf(ApiException.class);
    }

    @Test
    void rejectsNonPositivePageAndSize() {
        assertThatThrownBy(() -> PageBounds.require(0, 10)).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> PageBounds.require(1, 0)).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> PageBounds.requireSize(-1)).isInstanceOf(ApiException.class);
    }
}
