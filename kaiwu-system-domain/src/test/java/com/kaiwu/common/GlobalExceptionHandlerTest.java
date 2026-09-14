package com.kaiwu.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.validation.BeanPropertyBindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

class GlobalExceptionHandlerTest {

    @Test
    void exposesStableMessageKeyAndArgsWhileKeepingFallbackMessage() {
        ApiException exception = new ApiException(
                HttpStatus.BAD_REQUEST, "导出结果过多", "api.user.export.tooManyRows", Map.of("limit", 20_000));

        var response = new GlobalExceptionHandler().handleApiFailure(exception);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().message()).isEqualTo("导出结果过多");
        assertThat(response.getBody().messageKey()).isEqualTo("api.user.export.tooManyRows");
        assertThat(response.getBody().messageArgs()).containsEntry("limit", 20_000);
    }

    @Test
    void oldErrorsRemainCompatibleWithoutMessageKey() {
        Result<Void> result = Result.error(400, "旧错误");

        assertThat(result.message()).isEqualTo("旧错误");
        assertThat(result.messageKey()).isNull();
        assertThat(result.messageArgs()).isNull();
    }

    /**
     * 路由不存在必须是 404。落进 Exception 兜底分支时会变成 500 + ERROR 全栈，
     * 把"新接口还没部署上去"伪装成"服务坏了"，排查方向直接被带偏。
     */
    @Test
    void missingRouteIsNotFoundInsteadOfServerError() {
        var exception = new NoResourceFoundException(
                HttpMethod.GET, "api/i18n/translations/export", "/api/i18n/translations/export");

        var response = new GlobalExceptionHandler().handleNoResource(exception);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().code()).isEqualTo(404);
        assertThat(response.getBody().messageKey()).isEqualTo("api.common.notFound");
    }

    @Test
    void validationKeepsDetailedFallbackButDoesNotInjectChineseIntoLocalizedMessage() {
        var target = new Object();
        var bindingResult = new BeanPropertyBindingResult(target, "request");
        bindingResult.addError(new FieldError("request", "username", "用户名不能为空"));
        var exception = new MethodArgumentNotValidException(null, bindingResult);

        var response = new GlobalExceptionHandler().handleValidation(exception);

        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().message()).isEqualTo("用户名不能为空");
        assertThat(response.getBody().messageKey()).isEqualTo("api.validation.failed");
        assertThat(response.getBody().messageArgs()).isNull();
    }
}
