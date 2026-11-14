# 第三方声明

## 达梦 JDBC 驱动

System 与达梦迁移器均包含 `com.dameng:DmJdbcDriver11:8.1.5.45`。Maven Central POM 声明 Apache License 2.0。以下为 jar 内 `META-INF/license.txt` 的所有权声明、再分发条件及免责声明。[Maven Central 制品](https://repo.maven.apache.org/maven2/com/dameng/DmJdbcDriver11/8.1.5.45/)

JAR SHA-256 为 `7b3cfaceb96ba703034dfe002626c8445dfa4ae141bb4095b009cdf23ec3ce1a`。

```text
Dameng JDBC Using License
------------------------------------------------------------------------------------------------
Ownership

DAMENG(DM) or its licensors retain all ownership and intellectual property rights to the Programs.

-------------------------------------------------------------------------------------------------
Disclaimer of Warranties; Limitation of Liability

Redistribution and use in binary forms, with or without modification, are permitted provided that following conditions are met:
1. Redistribution in binary form must reproduce the above copyright notice, the list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.


THE PROGRAMS ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND. DAMENG(DM) FURTHER DISCLAIMS ALL WARRANTIES,
EXPRESS AND IMPLIED, INCLUDING WITHOUT LIMITATION, ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR
A PARTICULAR PURPOSE, OR NONINFRINGEMENT.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW WILL DAMENG(DM) BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL,
SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING
BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES
OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN
ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

Last updated: 10 September 2025
```

## Flyway 达梦插件

达梦迁移器包含 `io.github.maydear:flyway-database-dm8:12.11.0`，父 POM `flyway-database-support:12.11.0` 声明 Apache License 2.0。[插件制品](https://repo.maven.apache.org/maven2/io/github/maydear/flyway-database-dm8/12.11.0/) · [许可全文](https://www.apache.org/licenses/LICENSE-2.0)

Kaiwu 在迁移器中提供同名的 `io.github.maydear.flyway.database.dameng8.Dameng8Schema` 覆盖类。它在判断 Schema 是否为空时排除代表 Schema 自身的 SCH 记录，并禁止插件创建、删除或清空用户。运行镜像将迁移器 classes 放在插件 jar 前。
