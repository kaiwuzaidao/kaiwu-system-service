package com.kaiwu.module.operation.protocol;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeFormatterBuilder;

/** D05 投影正文的规范编码；调用方仍需单独认证生产者、校验业务字段与时间窗口。 */
public final class ManagedTodoDigest {
    private static final DateTimeFormatter UTC_MICROS =
            new DateTimeFormatterBuilder().appendInstant(6).toFormatter();

    /** 摘要编码只能通过静态协议函数完成，实例不能持有可变投递正文。 */
    private ManagedTodoDigest() {}

    /** 摘要输入使用授权后的生产者编码，不接受业务请求自报的生产者身份。 */
    public record Operation(
            String projectCode,
            String producerService,
            String bizKey,
            long recipientUserId,
            long sequence,
            String state,
            boolean terminal,
            Instant operationCreatedAt,
            String title,
            String content,
            String linkUrl,
            Instant dueAt) {}

    /** 固定字段顺序与空值标记保留 Unicode 原样和 null/空串区别。 */
    public static byte[] encode(Operation operation) {
        if (operation == null
                || operation.projectCode() == null
                || operation.producerService() == null
                || operation.bizKey() == null
                || operation.recipientUserId() <= 0
                || operation.sequence() <= 0
                || operation.state() == null
                || operation.operationCreatedAt() == null)
            throw new IllegalArgumentException("incomplete managed todo operation");
        var output = new ByteArrayOutputStream();
        write(output, operation.projectCode());
        write(output, operation.producerService());
        write(output, operation.bizKey());
        write(output, Long.toString(operation.recipientUserId()));
        write(output, Long.toString(operation.sequence()));
        write(output, operation.state());
        write(output, Boolean.toString(operation.terminal()));
        write(output, format(operation.operationCreatedAt()));
        write(output, operation.title());
        write(output, operation.content());
        write(output, operation.linkUrl());
        write(output, format(operation.dueAt()));
        return output.toByteArray();
    }

    /** 服务端独立计算 SHA-256，不能信任客户端传入的摘要。 */
    public static byte[] sha256(Operation operation) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(encode(operation));
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 unavailable", ex);
        }
    }

    /** 超过微秒精度时拒绝，避免数据库截断造成同版本摘要分叉。 */
    private static String format(Instant value) {
        if (value == null) return null;
        if (value.getNano() % 1000 != 0) throw new IllegalArgumentException("time precision exceeds microseconds");
        return UTC_MICROS.format(value);
    }

    /** 每个字段以存在标识和四字节大端长度分隔。 */
    private static void write(ByteArrayOutputStream output, String value) {
        if (value == null) {
            output.write(0);
            return;
        }
        byte[] bytes;
        try {
            var encoded = StandardCharsets.UTF_8.newEncoder().encode(java.nio.CharBuffer.wrap(value));
            bytes = new byte[encoded.remaining()];
            encoded.get(bytes);
        } catch (java.nio.charset.CharacterCodingException ex) {
            throw new IllegalArgumentException("invalid Unicode text", ex);
        }
        output.write(1);
        output.writeBytes(ByteBuffer.allocate(4).putInt(bytes.length).array());
        output.writeBytes(bytes);
    }
}
