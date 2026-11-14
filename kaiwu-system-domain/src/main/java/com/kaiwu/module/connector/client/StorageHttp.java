package com.kaiwu.module.connector.client;

import java.io.IOException;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpTimeoutException;

/** 签发器共用的 HTTP 发送与错误归一化；所有错误消息都不含请求头或请求体。 */
final class StorageHttp {

    /** 工具类不实例化。 */
    private StorageHttp() {}

    /**
     * 发送请求并读取文本响应。
     *
     * @param client 已应用出站策略的客户端
     * @param request 请求
     * @param target 用于错误消息的目标描述，如“STS”
     * @return 响应
     * @throws IllegalStateException 超时、网络失败或线程中断时抛出
     */
    static HttpResponse<String> send(HttpClient client, HttpRequest request, String target) {
        try {
            return client.send(request, HttpResponse.BodyHandlers.ofString());
        } catch (HttpTimeoutException exception) {
            throw new IllegalStateException("连接" + target + "超时", exception);
        } catch (IOException exception) {
            throw new IllegalStateException(
                    "无法连接" + target + "：" + exception.getClass().getSimpleName(), exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("请求" + target + "时线程被中断", exception);
        }
    }

    /**
     * 截取响应体中的错误码，供界面展示；不回显完整响应，避免把对端内部信息带到界面。
     *
     * @param body 响应体
     * @param openTag 错误码开始标记
     * @param closeTag 错误码结束标记
     * @return 错误码，找不到时返回空字符串
     */
    static String between(String body, String openTag, String closeTag) {
        if (body == null) {
            return "";
        }
        int start = body.indexOf(openTag);
        if (start < 0) {
            return "";
        }
        int end = body.indexOf(closeTag, start + openTag.length());
        if (end < 0) {
            return "";
        }
        String value = body.substring(start + openTag.length(), end).trim();
        return value.length() > 120 ? value.substring(0, 120) : value;
    }
}
