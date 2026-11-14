package ${basePackage}.common;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 统一异常出口。
 *
 * <p>响应同时给出服务端语言的 {@code message} 与稳定的 {@code messageKey}：前端按当前
 * 界面语言翻译 key，翻译缺失时回退 message，因此新增语言不需要改后端。</p>
 *
 * <p>未预期异常只返回通用 key，具体堆栈只进日志——把内部错误细节回给客户端等于泄露实现。</p>
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    /**
     * 将业务异常映射为保留国际化信息的 HTTP 响应。
     *
     * @param exception 已验证且可安全对外的业务异常
     * @return 对应状态和统一响应外壳
     */
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<Result<Void>> handleApi(ApiException exception) {
        return ResponseEntity.status(exception.getStatus()).body(Result.error(
                exception.getStatus().value(), exception.getMessage(),
                exception.getMessageKey(), exception.getMessageArgs()));
    }

    /**
     * 汇总 Bean Validation 的字段错误并以通用国际化标识返回。
     *
     * @param exception 请求参数校验异常
     * @return HTTP 400 统一响应
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Result<Void>> handleValidation(
            MethodArgumentNotValidException exception
    ) {
        // 校验详情保留在 message 里；key 用通用值，避免为每条校验规则造一个 key。
        String detail = exception.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .collect(Collectors.joining("; "));
        Map<String, Object> args = new LinkedHashMap<>();
        args.put("detail", detail);
        return ResponseEntity.badRequest().body(Result.error(
                HttpStatus.BAD_REQUEST.value(), detail, "error.validation.failed", args));
    }

    /**
     * 记录未预期异常的完整堆栈，并向客户端隐藏实现细节。
     *
     * @param exception 未分类异常
     * @return 使用通用错误标识的 HTTP 500 响应
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Result<Void>> handleUnexpected(Exception exception) {
        log.error("未预期异常", exception);
        return ResponseEntity.internalServerError().body(Result.error(
                HttpStatus.INTERNAL_SERVER_ERROR.value(), "服务内部错误",
                "error.internal", null));
    }
}
