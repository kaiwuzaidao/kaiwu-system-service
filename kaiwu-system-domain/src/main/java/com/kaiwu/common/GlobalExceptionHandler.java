package com.kaiwu.common;

import com.kaiwu.module.auth.AuthFailureException;
import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

/**
 * 最小 API 错误协议。
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger LOG = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    /** 认证失败：按异常自带的状态码与稳定 messageKey 输出，不额外包装。 */
    @ExceptionHandler(AuthFailureException.class)
    public ResponseEntity<Result<Void>> handleAuthFailure(AuthFailureException exception) {
        return ResponseEntity.status(exception.getStatus())
                .body(Result.error(
                        exception.getStatus().value(),
                        exception.getMessage(),
                        exception.getMessageKey(),
                        exception.getMessageArgs()));
    }

    /** 明确的业务错误：状态码与 messageKey 由抛出点决定。 */
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<Result<Void>> handleApiFailure(ApiException exception) {
        return ResponseEntity.status(exception.getStatus())
                .body(Result.error(
                        exception.getStatus().value(),
                        exception.getMessage(),
                        exception.getMessageKey(),
                        exception.getMessageArgs()));
    }

    /** Bean Validation 失败：只取第一条字段错误，避免把整串校验细节暴露给调用方。 */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Result<Void>> handleValidation(MethodArgumentNotValidException exception) {
        String message = exception.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(error -> error.getDefaultMessage())
                .orElse("请求参数错误");
        return ResponseEntity.badRequest().body(Result.error(400, message, "api.validation.failed", null));
    }

    @ExceptionHandler({
        MissingServletRequestParameterException.class,
        MethodArgumentTypeMismatchException.class,
        HttpMessageNotReadableException.class,
        ConstraintViolationException.class
    })
    public ResponseEntity<Result<Void>> handleRequestContract(Exception exception) {
        return ResponseEntity.badRequest().body(Result.error(400, "请求参数错误", "api.validation.failed", null));
    }

    /**
     * 没有任何 handler 匹配的路径。
     *
     * <p>Spring Boot 默认让静态资源兜底，未命中时抛 {@link NoResourceFoundException}，
     * 它原本落进下面的 {@code Exception} 兜底分支被当成 500。后果是：拼错的 URL、
     * 还没部署上去的新接口，都会报"服务处理失败"并打一条 ERROR 全栈——既误导排查方向
     * （像服务坏了，其实是路由不存在），又让任何人都能用一串不存在的路径刷 ERROR 日志。
     * 这里按语义回 404 并复用已种入的 {@code api.common.notFound}，日志降到 DEBUG。
     */
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<Result<Void>> handleNoResource(NoResourceFoundException exception) {
        LOG.debug("请求路径没有匹配的 handler：{}", exception.getResourcePath());
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(Result.error(404, "请求的资源不存在", "api.common.notFound", null));
    }

    /** 未预期异常只返回安全通用文案；堆栈留在服务日志，禁止把内部结构泄露给调用方。 */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Result<Void>> handleUnexpected(Exception exception) {
        LOG.error("未处理的 API 异常", exception);
        return ResponseEntity.internalServerError()
                .body(Result.error(500, "服务处理失败，请稍后重试", "api.common.internalError", null));
    }
}
