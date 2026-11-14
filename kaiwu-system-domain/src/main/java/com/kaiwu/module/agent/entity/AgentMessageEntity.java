package com.kaiwu.module.agent.entity;

import com.baomidou.mybatisplus.annotation.*;

/** Private persistence entity. */
@TableName("sys_agent_message")
public class AgentMessageEntity {
    @TableId(type = IdType.INPUT)
    private String id;

    private String conversationId;
    private String requestId;
    private String question;
    private String answer;
    private Boolean completed;
    private java.time.LocalDateTime createdAt;

    public String getId() {
        return id;
    }

    public void setId(String value) {
        id = value;
    }

    public String getConversationId() {
        return conversationId;
    }

    public void setConversationId(String value) {
        conversationId = value;
    }

    public String getRequestId() {
        return requestId;
    }

    public void setRequestId(String value) {
        requestId = value;
    }

    public String getQuestion() {
        return question;
    }

    public void setQuestion(String value) {
        question = value;
    }

    public String getAnswer() {
        return answer;
    }

    public void setAnswer(String value) {
        answer = value;
    }

    public Boolean getCompleted() {
        return completed;
    }

    public void setCompleted(Boolean value) {
        completed = value;
    }

    public java.time.LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(java.time.LocalDateTime value) {
        createdAt = value;
    }
}
