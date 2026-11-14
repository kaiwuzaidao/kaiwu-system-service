package io.github.maydear.flyway.database.dameng8;

import java.sql.SQLException;
import org.flywaydb.core.api.FlywayException;
import org.flywaydb.core.internal.database.base.Schema;
import org.flywaydb.core.internal.jdbc.JdbcTemplate;

/**
 * 固定版本达梦插件的 Schema 适配补丁。
 *
 * <p>12.11.0 上游把 ALL_OBJECTS 中 Schema 自身的 SCH 记录计入非空对象，导致全新用户也无法
 * migrate。本实现仅排除 SCH，并禁止插件创建、删除或清空用户。运行时必须让本模块 classes
 * 排在上游 JAR 前；真实数据库契约测试覆盖该装配。</p>
 */
public class Dameng8Schema extends Schema<Dameng8Database, Dameng8Table> {

    /** 复用上游连接与历史表实现，只替换 Schema 管理边界。 */
    Dameng8Schema(JdbcTemplate jdbcTemplate, Dameng8Database database, String name) {
        super(jdbcTemplate, database, name);
    }

    /** 仅接入部署方已建立的独立用户。 */
    @Override
    protected boolean doExists() throws SQLException {
        return jdbcTemplate.queryForInt("SELECT COUNT(*) FROM ALL_USERS WHERE USERNAME = ?", name) == 1;
    }

    /** Schema 自身不是应用对象，其余对象均阻止自动初始化。 */
    @Override
    protected boolean doEmpty() throws SQLException {
        return jdbcTemplate.queryForInt(
                        "SELECT COUNT(*) FROM ALL_OBJECTS WHERE OWNER = ? AND OBJECT_TYPE <> 'SCH'", name)
                == 0;
    }

    /** 数据库账号由部署方管理，迁移工具不创建账号。 */
    @Override
    protected void doCreate() {
        throw new FlywayException("请先创建独立的 Kaiwu 达梦用户与 Schema");
    }

    /** 禁止迁移工具删除账号。 */
    @Override
    protected void doDrop() {
        throw new FlywayException("Kaiwu 禁止删除达梦 Schema");
    }

    /** 禁止迁移工具清空应用数据。 */
    @Override
    protected void doClean() {
        throw new FlywayException("Kaiwu 禁止 clean 达梦 Schema");
    }

    /** 枚举当前 Schema 的普通表，保留上游历史表查询方式。 */
    @Override
    protected Dameng8Table[] doAllTables() throws SQLException {
        return jdbcTemplate.queryForStringList("SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = ?", name).stream()
                .map(this::getTable)
                .toArray(Dameng8Table[]::new);
    }

    /** 复用上游表存在性与历史表锁实现。 */
    @Override
    public Dameng8Table getTable(String tableName) {
        return new Dameng8Table(jdbcTemplate, database, this, tableName);
    }
}
