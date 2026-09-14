package com.kaiwu.module.system.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.kaiwu.common.Result;
import com.kaiwu.module.system.vo.HelloView;
import org.junit.jupiter.api.Test;

class HelloControllerTest {

    @Test
    void returnsThreeModuleArchitectureMarker() {
        Result<HelloView> result = new HelloController().hello();

        assertThat(result.code()).isZero();
        assertThat(result.data().service()).isEqualTo("kaiwu-system-service");
        assertThat(result.data().architecture()).isEqualTo("gateway + api/domain/boot");
    }
}
