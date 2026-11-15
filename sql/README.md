# 数据库初始化

Kaiwu v0.2.0 的空库初始化分两步：先创建表、索引和约束（DDL），再写入平台内置数据（DML），包括菜单、权限、字典和多语言文案。MySQL 与达梦各有一套脚本，按实际数据库选择一行。

| 数据库 | ① 建表和索引 | ② 写入初始数据 |
| --- | --- | --- |
| MySQL 8.4 | [mysql-01-ddl.sql](https://github.com/kaiwuzaidao/kaiwu-system-service/releases/download/v0.2.0/mysql-01-ddl.sql) | [mysql-02-dml.sql](https://github.com/kaiwuzaidao/kaiwu-system-service/releases/download/v0.2.0/mysql-02-dml.sql) |
| 达梦 DM8 | [dm8-01-ddl.sql](https://github.com/kaiwuzaidao/kaiwu-system-service/releases/download/v0.2.0/dm8-01-ddl.sql) | [dm8-02-dml.sql](https://github.com/kaiwuzaidao/kaiwu-system-service/releases/download/v0.2.0/dm8-02-dml.sql) |

**安装平台**时，给 Compose 或 Helm 准备空数据库即可。迁移任务会一次性完成以上两步并登记 Flyway 历史。使用入口仓在本机启动 MySQL 版：

```sh
KAIWU_DB_TYPE=mysql ./kaiwu up
```

**单独查看或复现数据库**时，可在独立空库中依次执行同一行的两个文件。手工导入只创建结构和种子，不登记 Flyway 历史，请为平台安装另备空库。DM8 须先按[数据库配置](../docs/DATABASES.md#达梦)准备实例和独立 Schema。

两个下载文件按顺序拼接，内容与 v0.2.0 的原始迁移逐字节相同：[MySQL 基线](increment/V127__kaiwu_baseline.sql) · [DM8 基线](dm/V127__kaiwu_baseline.sql)。每种数据库首次安装只执行这一份基线；`127` 是 Flyway 的起始版本号。
