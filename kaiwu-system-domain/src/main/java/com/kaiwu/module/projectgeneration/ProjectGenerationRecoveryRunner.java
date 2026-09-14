package com.kaiwu.module.projectgeneration;

import com.kaiwu.common.ApiException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
@Order(50)
public class ProjectGenerationRecoveryRunner implements ApplicationRunner {

    private static final Logger LOGGER = LoggerFactory.getLogger(ProjectGenerationRecoveryRunner.class);

    private final ProjectGenerationRepository repository;
    private final ProjectGenerationService service;

    public ProjectGenerationRecoveryRunner(ProjectGenerationRepository repository, ProjectGenerationService service) {
        this.repository = repository;
        this.service = service;
    }

    @Override
    public void run(ApplicationArguments args) {
        repository.recoverInterruptedPushes();
        repository.recoverableTaskNos().forEach(this::enqueueSafely);
    }

    private void enqueueSafely(String taskNo) {
        try {
            service.enqueue(taskNo);
        } catch (ApiException exception) {
            if (exception.getStatus() != HttpStatus.SERVICE_UNAVAILABLE) {
                throw exception;
            }
            // enqueue 已把该 PENDING 任务补偿为 FAILED；启动恢复继续处理剩余任务。
            LOGGER.warn("恢复项目生成任务时执行队列已满：taskNo={}, messageKey={}", taskNo, exception.getMessageKey());
        }
    }
}
