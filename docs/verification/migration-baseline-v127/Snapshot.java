import java.nio.file.*;
import java.sql.*;
import java.util.*;

/** 从一次性迁移验收库导出结构和所有平台行，按依赖顺序生成可重放文本。 */
class Snapshot {
    private final Connection db;
    private final boolean mysql;
    private final String schema;
    private final boolean old;
    private final boolean publicComparison;
    private final Path out;
    private final Map<String, Set<Long>> omitted =
            Map.of(
                    "sys_dict_type", Set.of(9200000000000004600L, 9200000000000004601L),
                    "sys_dict_item",
                            Set.of(
                                    9200000000000004610L,
                                    9200000000000004611L,
                                    9200000000000004620L,
                                    9200000000000004621L,
                                    9200000000000004622L,
                                    9200000000000004623L,
                                    9200000000000004624L),
                    "sys_i18n_message",
                            Set.of(
                                    9200000000000004650L,
                                    9200000000000004651L,
                                    9200000000000004652L,
                                    9200000000000004653L,
                                    9200000000000004654L,
                                    9200000000000004655L,
                                    9200000000000004656L,
                                    9200000000000004657L,
                                    9200000000000004660L,
                                    9200000000000004661L,
                                    9200000000000004662L,
                                    9200000000000004663L,
                                    9200000000000004664L,
                                    9200000000000004665L,
                                    9200000000000004666L));

    /** 连接明确指定的本机一次性实例，按比较模式设置排除范围。 */
    Snapshot(Connection db, boolean mysql, String schema, String mode, Path out) {
        this.db = db;
        this.mysql = mysql;
        this.schema = schema;
        this.old = mode.equals("full-old");
        this.publicComparison = mode.equals("public");
        this.out = out;
    }

    /** 读取原生目录查询的所有列，保留数据库的 DDL 和约束信息。 */
    List<String[]> query(String sql) throws SQLException {
        try (var st = db.createStatement();
                var rs = st.executeQuery(sql)) {
            var rows = new ArrayList<String[]>();
            int n = rs.getMetaData().getColumnCount();
            while (rs.next()) {
                var r = new String[n];
                for (int i = 0; i < n; i++) r[i] = rs.getString(i + 1);
                rows.add(r);
            }
            return rows;
        }
    }

    /** 去除当前临时 Schema 的限定名，使两个独立 Schema 的结构可逐值比对。 */
    String ddl(String ddl) {
        return ddl.replace("\r", "")
                        .replace("\"" + schema + "\".", "")
                        .strip()
                        .replaceFirst(";\\s*$", "")
                        .strip()
                + ";\n";
    }

    /** 对验证库的对象名使用当前方言的标识符引号。 */
    String id(String name) {
        if (!name.matches("[a-zA-Z_][a-zA-Z_0-9]*")) throw new IllegalArgumentException(name);
        return mysql ? "`" + name + "`" : "\"" + name + "\"";
    }

    /** 按数据库类型序列化列值，保留空值、字符串转义与时间精度。 */
    String value(ResultSet rs, int i) throws SQLException {
        var md = rs.getMetaData();
        var t = md.getColumnTypeName(i).toUpperCase(Locale.ROOT);
        String s = rs.getString(i);
        if (s == null) return "NULL";
        if (t.equals("BIT") || t.equals("BOOLEAN")) return rs.getBoolean(i) ? "1" : "0";
        if (Set.of(
                        "INT",
                        "INTEGER",
                        "TINYINT",
                        "SMALLINT",
                        "BIGINT",
                        "DECIMAL",
                        "NUMERIC",
                        "NUMBER")
                .contains(t)) return rs.getBigDecimal(i).toPlainString();
        if (t.contains("BINARY"))
            return (mysql ? "X'" : "HEXTORAW('")
                    + HexFormat.of().formatHex(rs.getBytes(i))
                    + (mysql ? "'" : "')");
        if (mysql) s = s.replace("\\", "\\\\").replace("\0", "\\0");
        return "'" + s.replace("'", "''") + "'";
    }

    /** 按外键依赖导出表结构，随后逐表导出主键白名单以外的所有种子。 */
    void export() throws Exception {
        Files.createDirectories(out);
        var tables = new TreeMap<String, Set<String>>();
        String list =
                mysql
                        ? "SELECT table_name FROM information_schema.tables WHERE"
                              + " table_schema=database() AND table_type='BASE TABLE'"
                        : "SELECT table_name FROM user_tables";
        for (var r : query(list))
            if (!r[0].equalsIgnoreCase("flyway_schema_history")) tables.put(r[0], new TreeSet<>());
        String refs =
                mysql
                        ? "SELECT table_name,referenced_table_name FROM"
                              + " information_schema.referential_constraints WHERE"
                              + " constraint_schema=database()"
                        : "SELECT c.table_name,p.table_name FROM user_constraints c JOIN"
                              + " user_constraints p ON p.constraint_name=c.r_constraint_name WHERE"
                              + " c.constraint_type='R'";
        for (var r : query(refs)) if (!r[0].equals(r[1])) tables.get(r[0]).add(r[1]);
        if (publicComparison && !tables.containsKey("sys_i18n_catalog_revision"))
            throw new IllegalStateException("缺少文案目录表");
        var order = new ArrayList<String>();
        while (order.size() < tables.size()) {
            int before = order.size();
            for (var e : tables.entrySet())
                if (!order.contains(e.getKey()) && order.containsAll(e.getValue()))
                    order.add(e.getKey());
            if (before == order.size()) throw new IllegalStateException("循环外键");
        }
        var all = new StringBuilder();
        for (var table : order) {
            var structure = new StringBuilder();
            if (mysql) structure.append(ddl(query("SHOW CREATE TABLE " + id(table)).getFirst()[1]));
            else {
                structure.append(
                        ddl(
                                query(
                                                "SELECT DBMS_METADATA.GET_DDL('TABLE','"
                                                        + table
                                                        + "',USER) FROM dual")
                                        .getFirst()[0]));
                for (var row :
                        query(
                                "SELECT DBMS_METADATA.GET_DDL('INDEX',index_name,USER) FROM"
                                    + " user_indexes WHERE table_name='"
                                        + table
                                        + "' AND generated='N' ORDER BY index_name"))
                    structure.append(ddl(row[0]));
            }
            Files.writeString(out.resolve(table + ".ddl"), structure.toString());
            all.append(structure).append('\n');
        }
        for (var table : order) {
            var rows = new ArrayList<String>();
            var removed = new TreeSet<Long>();
            int platformCounters = 0;
            try (var st = db.createStatement();
                    var rs = st.executeQuery("SELECT * FROM " + id(table))) {
                var md = rs.getMetaData();
                int count = md.getColumnCount();
                var cols = new ArrayList<String>();
                for (int i = 1; i <= count; i++) cols.add(id(md.getColumnName(i)));
                String prefix =
                        "INSERT INTO " + id(table) + " (" + String.join(", ", cols) + ") VALUES\n";
                while (rs.next()) {
                    if (old
                            && omitted.containsKey(table)
                            && omitted.get(table).contains(rs.getLong("id"))) {
                        removed.add(rs.getLong("id"));
                        continue;
                    }
                    var fields = new ArrayList<String>();
                    // 公开旧链剔除了一次文案写入及其计数递增。客户端通过缓存版本相等判断是否刷新。
                    // 仅此对比忽略 platform 行的 revision、updated_at；完整旧链仍逐列逐值比较。
                    boolean platformCounter =
                            publicComparison
                                    && table.equalsIgnoreCase("sys_i18n_catalog_revision")
                                    && "platform".equals(rs.getString("catalog_code"));
                    if (platformCounter) platformCounters++;
                    for (int i = 1; i <= count; i++) {
                        String column = md.getColumnName(i);
                        if (platformCounter
                                && (column.equalsIgnoreCase("revision")
                                        || column.equalsIgnoreCase("updated_at"))) {
                            fields.add("<platform-counter>");
                        } else {
                            fields.add(value(rs, i));
                        }
                    }
                    rows.add(prefix + "(" + String.join(", ", fields) + ");\n");
                }
            }
            if (publicComparison
                    && table.equalsIgnoreCase("sys_i18n_catalog_revision")
                    && platformCounters != 1)
                throw new IllegalStateException("须恰有一条 platform 文案目录记录");
            if (old && !removed.equals(omitted.getOrDefault(table, Set.of())))
                throw new IllegalStateException(table + " 排除主键不齐 " + removed);
            Collections.sort(rows);
            String data = String.join("", rows);
            Files.writeString(out.resolve(table + ".rows"), data);
            all.append(data);
            System.out.println(table + " rows=" + rows.size() + " excluded=" + removed);
        }
        Files.writeString(
                out.resolve(publicComparison ? "comparison.txt" : "V127__kaiwu_baseline.sql"),
                all.toString());
    }

    /** 读取本地验证库，并在输出目录保存逐表结构和数据。 */
    public static void main(String[] args) throws Exception {
        boolean mysql = args[0].equals("mysql");
        int port = Integer.parseInt(args[1]);
        String schema = args[2];
        if (!schema.matches("[A-Za-z][A-Za-z0-9_]*")
                || !Set.of("full-old", "candidate", "public").contains(args[3]))
            throw new IllegalArgumentException("无效的 Schema 或比较模式");
        String url =
                (mysql ? "jdbc:mysql://" : "jdbc:dm://")
                        + "127.0.0.1:"
                        + port
                        + (mysql ? "/" + schema + "?allowPublicKeyRetrieval=true" : "");
        try (var c =
                DriverManager.getConnection(
                        url, mysql ? "root" : schema, System.getenv("R4_FIXTURE_PASSWORD"))) {
            new Snapshot(c, mysql, schema, args[3], Path.of(args[4])).export();
        }
    }
}
