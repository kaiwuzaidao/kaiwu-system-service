package com.kaiwu.module.operation.service;

import com.kaiwu.module.operation.dto.ManagedTodoRequest;
import com.kaiwu.module.operation.vo.ManagedTodoReceipt;

/** 项目服务身份限定的受管待办投递与回执。 */
public interface ManagedTodoService {
    /** 校验身份和版本后应用单个收件人投影。 */
    ManagedTodoReceipt put(String authorization, ManagedTodoRequest request);
    /** 查询当前生产者的单收件人回执。 */
    ManagedTodoReceipt receipt(String authorization, String key, String recipientId);
}
