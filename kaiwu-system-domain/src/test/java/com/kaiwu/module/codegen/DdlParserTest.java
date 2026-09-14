package com.kaiwu.module.codegen;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.kaiwu.common.ApiException;
import org.junit.jupiter.api.Test;

class DdlParserTest {

    private final DdlParser parser = new DdlParser();

    @Test
    void parsesMultipleCreateTablesAndMapsTypes() {
        var tables = parser.parseAll(
                """
                CREATE TABLE biz_order (
                    id BIGINT PRIMARY KEY,
                    amount DECIMAL(12,2),
                    created_at DATETIME
                );
                CREATE TABLE biz_order_item (
                    id BIGINT PRIMARY KEY,
                    title VARCHAR(100)
                );
                """);

        assertThat(tables).hasSize(2);
        assertThat(tables.getFirst().getEntityName()).isEqualTo("BizOrder");
        assertThat(tables.getFirst().getColumns())
                .extracting("javaType")
                .containsExactly("Long", "BigDecimal", "LocalDateTime");
    }

    @Test
    void acceptsStandaloneCreateIndexesAlongsideTables() {
        var tables = parser.parseAll(
                """
                CREATE TABLE reimburse_record (
                    id BIGINT PRIMARY KEY,
                    status VARCHAR(32)
                );
                CREATE INDEX idx_reimburse_record_status
                    ON reimburse_record (status);
                """);

        assertThat(tables).hasSize(1);
        assertThat(tables.getFirst().getTableName()).isEqualTo("reimburse_record");
    }

    @Test
    void parsesTableCommentWithoutEqualsSign() {
        var tables = parser.parseAll(
                """
                CREATE TABLE reimburse_prompt_config (
                    id BIGINT PRIMARY KEY COMMENT '主键'
                ) COMMENT '提示词配置';
                """);

        assertThat(tables.getFirst().getComment()).isEqualTo("提示词配置");
    }

    @Test
    void rejectsNonCreateStatement() {
        assertThatThrownBy(() -> parser.parseAll("DROP TABLE sys_user"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("仅支持 CREATE TABLE");
    }
}
