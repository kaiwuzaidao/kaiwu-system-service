package com.kaiwu.module.projectgeneration;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.projectgeneration.dto.MysqlSchemaImportRequest;
import com.kaiwu.module.projectgeneration.vo.MysqlSchemaImportView;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * 使用一次性凭据只读导入 MySQL 8 表结构。
 *
 * <p>请求与结果之外不保存连接信息；只读取 information_schema 和 SHOW CREATE TABLE。</p>
 */
@Service
public class MysqlSchemaImportService {

    private static final int MAX_TABLES = 200;
    private static final int MAX_COLUMNS = 5000;
    private static final int MAX_DDL_LENGTH = 500_000;

    private final ProjectFactoryAccessService accessService;

    public MysqlSchemaImportService(ProjectFactoryAccessService accessService) {
        this.accessService = accessService;
    }

    /**
     * 临时只读连接目标 MySQL，导出其表结构供生成蓝图参考。
     *
     * <p>只接受拆分的 host/port/database/username/password，不接受完整 JDBC URL；
     * 密码用完即弃，不落库、不进日志、不进入生成任务（CLAUDE.md 工程约束第 12 条）。</p>
     */
    public MysqlSchemaImportView importSchema(MysqlSchemaImportRequest request, String userId) {
        accessService.requireProjectAdmin(request.projectId(), userId);
        String host = validateHost(request.host());
        int port = request.port() == null ? 3306 : request.port();
        String database = request.database();
        String jdbcUrl = "jdbc:mysql://" + host + ":" + port + "/" + database
                + "?connectTimeout=5000&socketTimeout=15000"
                + "&useUnicode=true&characterEncoding=utf8"
                + "&serverTimezone=UTC&sslMode=PREFERRED"
                + "&allowMultiQueries=false";
        try (Connection connection = DriverManager.getConnection(jdbcUrl, request.username(), request.password())) {
            connection.setReadOnly(true);
            List<String> tables = tableNames(connection, database);
            if (tables.isEmpty()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "指定数据库中没有可导入的基础表", "api.common.badRequest");
            }
            if (tables.size() > MAX_TABLES) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "表数量超过上限 " + MAX_TABLES, "api.common.badRequest");
            }
            int columnCount = columnCount(connection, database);
            if (columnCount > MAX_COLUMNS) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "字段数量超过上限 " + MAX_COLUMNS, "api.common.badRequest");
            }
            StringBuilder ddl = new StringBuilder();
            for (String table : tables) {
                if (!ddl.isEmpty()) ddl.append("\n\n");
                ddl.append(showCreateTable(connection, database, table)).append(';');
                if (ddl.length() > MAX_DDL_LENGTH) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "导入 DDL 超过 500000 个字符", "api.common.badRequest");
                }
            }
            return new MysqlSchemaImportView(database, tables.size(), columnCount, ddl.toString());
        } catch (ApiException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new ApiException(
                    HttpStatus.BAD_GATEWAY, "无法只读获取 MySQL 表结构，请检查地址、账号权限和网络", "api.common.upstreamFailed");
        }
    }

    private List<String> tableNames(Connection connection, String database) throws Exception {
        try (PreparedStatement statement = connection.prepareStatement(
                """
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = ? AND table_type = 'BASE TABLE'
                ORDER BY table_name
                """)) {
            statement.setString(1, database);
            try (ResultSet rs = statement.executeQuery()) {
                List<String> tables = new ArrayList<>();
                while (rs.next()) {
                    tables.add(rs.getString(1));
                }
                return tables;
            }
        }
    }

    private int columnCount(Connection connection, String database) throws Exception {
        try (PreparedStatement statement = connection.prepareStatement(
                """
                SELECT COUNT(*)
                FROM information_schema.columns
                WHERE table_schema = ?
                """)) {
            statement.setString(1, database);
            try (ResultSet rs = statement.executeQuery()) {
                rs.next();
                return rs.getInt(1);
            }
        }
    }

    private String showCreateTable(Connection connection, String database, String table) throws Exception {
        String sql = "SHOW CREATE TABLE " + quote(database) + "." + quote(table);
        // MySQL 不支持绑定标识符；database 经 DTO 白名单校验，table 来自 information_schema，
        // quote() 还会对反引号做双写转义。
        try (Statement statement = connection.createStatement();
                ResultSet rs = statement.executeQuery(
                        sql)) { // nosemgrep: java.lang.security.audit.formatted-sql-string.formatted-sql-string
            if (!rs.next()) {
                throw new ApiException(HttpStatus.BAD_GATEWAY, "无法读取表结构：" + table, "api.common.upstreamFailed");
            }
            return rs.getString(2).replaceAll("\\sAUTO_INCREMENT=\\d+", "");
        }
    }

    private String validateHost(String value) {
        String host = value == null ? "" : value.trim();
        if (host.isEmpty()
                || host.contains("/")
                || host.contains("\\")
                || host.contains("?")
                || host.contains("#")
                || host.contains("@")
                || host.contains(":")) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST, "数据库主机只填写主机名或 IPv4，不填写协议、端口或 JDBC 参数", "api.common.badRequest");
        }
        return host;
    }

    private String quote(String identifier) {
        return "`" + identifier.replace("`", "``") + "`";
    }
}
