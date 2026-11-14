package com.kaiwu.module.connector.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;

/** 模型用途绑定；空值使用旧默认模型。 */
@TableName("sys_ai_model_route")
public class AiModelRouteEntity {
    @TableId(type = IdType.INPUT)
    private Long id;

    private Long planModelId;
    private Long answerModelId;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getPlanModelId() {
        return planModelId;
    }

    public void setPlanModelId(Long value) {
        this.planModelId = value;
    }

    public Long getAnswerModelId() {
        return answerModelId;
    }

    public void setAnswerModelId(Long value) {
        this.answerModelId = value;
    }
}
