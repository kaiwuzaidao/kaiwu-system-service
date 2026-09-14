package com.kaiwu.config;

import java.time.Clock;
import java.time.ZoneId;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 平台的时间源。
 *
 * <p>此前各处直接调 {@code LocalDateTime.now()}，取的是容器默认时区——容器 TZ 一变，
 * 写进库的 created_at/updated_at 就跟着变，而库里是不带时区的 datetime，偏移无从追溯。
 * 收敛成一个 Bean 后，时区是一处显式配置，且测试可以换成 {@link Clock#fixed} 冻结时间。</p>
 *
 * <p>默认值刻意留空，取 {@link ZoneId#systemDefault()}，与改造前的行为逐字节一致；
 * 要钉死时区就配 {@code kaiwu.time.zone: Asia/Shanghai}。注意改这个值会让新写入的
 * 时间戳相对存量行整体平移，属于数据语义变更，不要顺手改。</p>
 */
@Configuration
public class TimeConfiguration {

    @Bean
    public Clock clock(@Value("${kaiwu.time.zone:}") String zone) {
        return Clock.system(zone == null || zone.isBlank() ? ZoneId.systemDefault() : ZoneId.of(zone));
    }
}
