package com.kaiwu.database;

import io.github.maydear.flyway.database.dameng8.Dameng8Parser;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Locale;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.internal.parser.ParsingContext;
import org.flywaydb.core.internal.resource.StringResource;

/** 达梦离线迁移容器入口；只管理当前部署的独立 Schema，不提供清库或修复历史命令。 */
public final class DmMigrationMain {

    /** 工具类不创建业务对象。 */
    private DmMigrationMain() {}

    /** 先核对达梦实例前置条件，再通过 Flyway 校验或迁移当前平台库。 */
    public static void main(String[] args) throws Exception {
        String command = args.length == 0 ? "migrate" : args[0];
        if (!command.equals("migrate")
                && !command.equals("check")
                && !command.equals("sql")
                && !command.equals("baseline")) {
            throw new IllegalArgumentException("仅支持 check / migrate / sql / baseline");
        }
        String schema = required("DB_NAME");
        if (!schema.matches("[A-Za-z][A-Za-z0-9_]*")
                || java.util.Set.of("SYS", "SYSDBA", "SYSSSO", "SYSAUDITOR")
                        .contains(schema.toUpperCase(Locale.ROOT))) {
            throw new IllegalArgumentException("必须使用独立的 Kaiwu Schema");
        }
        String url = required("DB_JDBC_URL");
        if (!url.startsWith("jdbc:dm://")) {
            throw new IllegalArgumentException("达梦迁移必须使用 jdbc:dm:// URL");
        }
        String user = required("DB_USER");
        String password = required("DB_PASSWORD");
        if (command.equals("sql")) {
            executeSql(url, user, password);
            return;
        }
        try (Connection connection = DriverManager.getConnection(url, user, password)) {
            validateInstance(connection);
            if (!command.equals("baseline")) {
                rejectLegacyHistory(connection, schema);
            } else if (tableExists(connection, schema, "flyway_schema_history")
                    || !tableExists(connection, schema, "sys_project_backend_service")) {
                throw new IllegalStateException("人工 baseline 须在已备份、核对 V127 并移除旧历史的库执行。见 docs/UPGRADING.md#v127");
            }
        }
        Flyway flyway = Flyway.configure()
                .dataSource(url, user, password)
                .locations("filesystem:" + System.getenv().getOrDefault("MIGRATIONS_DIR", "/migrations"))
                .schemas(schema)
                .defaultSchema(schema)
                .createSchemas(false)
                .baselineVersion("127")
                .baselineOnMigrate(false)
                .cleanDisabled(true)
                .ignoreMigrationPatterns(new String[0])
                .connectRetries(10)
                .load();
        if (command.equals("baseline")) {
            flyway.baseline();
        } else if (command.equals("migrate")) {
            flyway.migrate();
            flyway.validate();
        } else {
            // 新安装允许 pending；已执行迁移的缺失、失败、校验和变化仍必须拒绝。
            Flyway.configure()
                    .configuration(flyway.getConfiguration())
                    .ignoreMigrationPatterns("*:pending")
                    .load()
                    .validate();
        }
    }

    /** 在目标 Schema 核对历史表，允许空库通过，只读拒绝旧链的成功或失败记录。 */
    private static void rejectLegacyHistory(Connection connection, String schema) throws SQLException {
        if (!tableExists(connection, schema, "flyway_schema_history")) {
            return;
        }
        int highest = 0;
        boolean legacy = false;
        try (var statement = connection.createStatement();
                var rows = statement.executeQuery("SELECT version, type, script, success FROM " + schema
                        + ".flyway_schema_history WHERE version IS NOT NULL")) {
            while (rows.next()) {
                int version = Integer.parseInt(rows.getString(1));
                if (rows.getBoolean(4)) {
                    highest = Math.max(highest, version);
                }
                if (version < 127
                        || (version == 127
                                && !"BASELINE".equals(rows.getString(2))
                                && !("SQL".equals(rows.getString(2))
                                        && "V127__kaiwu_baseline.sql".equals(rows.getString(3))))) {
                    legacy = true;
                }
            }
        }
        if (legacy) {
            String section = highest <= 44 ? "v44" : highest < 127 ? "v45-v126" : "v127";
            throw new IllegalStateException("旧迁移历史 V" + highest + "，请先按 docs/UPGRADING.md#" + section + " 处理");
        }
    }

    /** 按部署指定的 Schema 查询真实用户表，调用方可使用独立迁移账号。 */
    private static boolean tableExists(Connection connection, String schema, String table) throws SQLException {
        try (var statement = connection.prepareStatement(
                "SELECT COUNT(*) FROM all_tables WHERE UPPER(owner)=UPPER(?) AND UPPER(table_name)=UPPER(?)")) {
            statement.setString(1, schema);
            statement.setString(2, table);
            try (var rows = statement.executeQuery()) {
                rows.next();
                return rows.getInt(1) != 0;
            }
        }
    }

    /** 在创建历史表及平台表之前验证实例参数，避免不兼容实例留下半迁移状态。 */
    public static void validateInstance(Connection connection) throws Exception {
        try (Statement statement = connection.createStatement();
                ResultSet result =
                        statement.executeQuery("SELECT CASE_SENSITIVE(), SF_GET_UNICODE_FLAG(), SF_GET_PAGE_SIZE()")) {
            if (!result.next()) {
                throw new IllegalStateException("无法读取达梦实例参数");
            }
            if (result.getInt(1) != 0) {
                throw new IllegalStateException("达梦实例必须以 CASE_SENSITIVE=0 初始化");
            }
            if (result.getInt(2) != 1) {
                throw new IllegalStateException("达梦实例必须使用 UTF-8 字符集");
            }
            if (result.getInt(3) < 16 * 1024) {
                throw new IllegalStateException("达梦实例 PAGE_SIZE 至少为 16KB");
            }
        }
        // 仅查询内存中的生效值，不使用需 INI 管理权限的系统函数，也不读取文件值。
        try (Statement statement = connection.createStatement();
                ResultSet result =
                        statement.executeQuery("SELECT VALUE FROM SYS.V$PARAMETER WHERE NAME='COMPATIBLE_MODE'")) {
            if (!result.next() || result.getInt(1) != 4) {
                throw new IllegalStateException("达梦实例必须启用 COMPATIBLE_MODE=4 并重启生效");
            }
        } catch (SQLException failure) {
            throw new IllegalStateException("无法读取达梦兼容模式，请确认连接正常且迁移用户具有 SYS.V$PARAMETER 的 SELECT 权限", failure);
        }
    }

    /** 执行由本机管理命令明确提供的 SQL，结果按行输出；密码只从容器环境读取。 */
    private static void executeSql(String url, String user, String password) throws Exception {
        String sql = new String(System.in.readAllBytes(), StandardCharsets.UTF_8);
        var parser = new Dameng8Parser(Flyway.configure().placeholderReplacement(false), new ParsingContext());
        try (var statements = parser.parse(new StringResource(sql));
                Connection connection = DriverManager.getConnection(url, user, password);
                Statement statement = connection.createStatement()) {
            connection.setAutoCommit(false);
            while (statements.hasNext()) {
                if (statement.execute(statements.next().getSql())) {
                    try (ResultSet result = statement.getResultSet()) {
                        while (result.next()) {
                            System.out.println(result.getString(1));
                        }
                    }
                }
            }
            connection.commit();
        }
    }

    /** 缺少连接参数时在建立连接前退出，错误信息不包含参数值。 */
    private static String required(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("缺少环境变量：" + name);
        }
        return value;
    }
}
