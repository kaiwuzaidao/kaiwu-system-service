import org.flywaydb.core.Flyway;

/**
 * 对本地一次性 MySQL 执行 System 的 Flyway 迁移（与 docker-compose 的 db-migrate 同一份 sql/increment）。
 *
 * <p>用法：{@code java -cp <classpath> Migrate.java <jdbcUrl> <user> <password> <sqlDir>}。
 * 不用 flyway 镜像，是因为内网拉不到 Docker Hub，且本机内存只有 2 GiB，少起一个容器。</p>
 */
public class Migrate {
    public static void main(String[] args) {
        var result = Flyway.configure()
                .dataSource(args[0], args[1], args[2])
                .locations("filesystem:" + args[3])
                .load()
                .migrate();
        System.out.println("migrated: " + result.migrationsExecuted + " -> " + result.targetSchemaVersion);
    }
}
