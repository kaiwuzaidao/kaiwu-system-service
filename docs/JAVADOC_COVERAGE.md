# Kaiwu System Service 中文 Javadoc 覆盖基线

审计日期：2026-10-15
规范：JAVA_STYLE.md

本清单由 ChineseJavadocConventionTest 使用 JDK 编译器 AST 统计，覆盖 `src/main/java`
与 `src/test/java` 中源码显式声明的具名类型、构造器和方法。缺少中文 Javadoc 的数量不得超过
下列基线；每次补齐一批注释都应下调对应数字，直至全部为 0。匿名类、编译器生成的 record
accessor 和 Lombok 生成成员不计入数量。

| 源码目录 | 当前缺口上限 |
| --- | ---: |
| kaiwu-system-api / src/main/java | 85 |
| kaiwu-system-domain / src/main/java | 2645 |
| kaiwu-system-boot / src/main/java | 1 |
| kaiwu-system-domain / src/test/java | 606 |
| kaiwu-system-boot / src/test/java | 4 |
| **合计** | **3341** |

该门禁只验证中文 Javadoc 是否存在，不能判断文字是否解释了职责或边界。新增和改动代码的注释质量仍由
评审按 JAVA_STYLE.md 判断；不得以批量生成的重复句式代替真实说明。
