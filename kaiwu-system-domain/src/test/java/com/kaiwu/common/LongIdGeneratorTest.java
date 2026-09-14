package com.kaiwu.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.HashSet;
import java.util.Set;
import org.junit.jupiter.api.Test;

class LongIdGeneratorTest {

    @Test
    void generatesPositiveUniqueBigintValues() {
        Set<String> values = new HashSet<>();
        for (int index = 0; index < 10_000; index++) {
            String value = LongIdGenerator.nextId();
            assertThat(Long.parseLong(value)).isPositive();
            assertThat(values.add(value)).isTrue();
        }
    }
}
