# Kaiwu 项目工厂

项目工厂只生成符合 Kaiwu 规范的前后端基础脚手架，不调用 AI，也不根据 DDL 生成业务模块。

1. 登记业务项目并配置成员。
2. 创建基础脚手架生成任务，完成后下载前后端两个 ZIP，或通过 `./kaiwu project pull` 取回。
3. 在独立业务仓库中使用 AI 编程工具，遵循生成的 `AGENTS.md`、约束文件和项目测试继续开发。

一个项目只允许成功生成一次；成功后的制品不覆盖，已完成的历史任务仍可查看和下载。历史 DDL 任务不能重新提交或重试，已经排队或执行的旧任务仍按原输入完成。平台不再提供 MySQL 表结构导入接口。

CLI：`./kaiwu project new <项目编码> --name <项目名称> [--package <基础包名>]`。

接口：`POST /api/project-generations` 使用 `generationMode=BASIC_SCAFFOLD`，状态、重试与下载通过 `/api/project-generations/{taskNo}` 相关接口完成。业务权限、菜单、字典及配置由生成项目后续通过清单同步。

### 取回早期生成的项目

如果 v0.2.0 生成的业务后端提示缺少配置，或业务前端 Nginx 提示无法读取 `default.conf`，可用修复后的 CLI 将同一份制品取回到新目录。下面以订单中心为例。

```bash
./kaiwu project pull order-center --dir ../business-recovered
./kaiwu project-up ../business-recovered/order-center-service ../business-recovered/order-center-web
```

新目录保存的是最初生成的代码。已有业务改动请先在原仓提交，再迁移到新工作树。启动命令会检查业务后端的 readiness 和平台下的前端入口，两个地址都可访问后才登记入口。

早期设计与已下线接口见 [历史记录](PROJECT_FACTORY-legacy.md)，仅供追溯。
