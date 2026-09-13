# 备份与恢复

## 1. 备份内容

一次完整备份包含：

- PostgreSQL 业务数据库。
- `/app/uploads` 中的材料、项目和颜色变化图片。
- `SHA256SUMS` 校验文件。

库存流水、审计日志、用户和会话表都在 PostgreSQL 备份中。

## 2. 创建备份

```bash
cd origin
BACKUP_DIR=./backups ./ops/backup.sh
```

输出目录示例：

```text
backups/20260913T021500Z/
├── database.dump
├── attachments.tar.gz
└── SHA256SUMS
```

脚本会在备份期间短暂停止 Web 和 API，确保数据库快照与附件卷一致；备份完成或脚本失败退出时会自动恢复原先运行的服务。

建议：

- 每日备份一次。
- 至少保留 14 天。
- 将备份复制到不同磁盘或对象存储。
- 定期在独立环境执行恢复演练。
- 不要只备份数据库而忽略附件卷。

## 3. 校验备份

macOS：

```bash
cd backups/20260913T021500Z
shasum -a 256 -c SHA256SUMS
```

Linux：

```bash
cd backups/20260913T021500Z
sha256sum -c SHA256SUMS
```

校验失败时不要使用该备份。

## 4. 恢复

恢复会覆盖当前数据库和附件，执行前必须确认目标环境。

```bash
cd origin
./ops/restore.sh "$(pwd)/backups/20260913T021500Z"
```

脚本会：

1. 停止 Web 和 API 写入。
2. 删除并重建当前数据库。
3. 使用 `pg_restore` 恢复数据库。
4. 使用当前 API 镜像挂载附件卷并恢复文件。
5. 重新启动所有服务。

恢复完成后执行：

```bash
curl -f http://127.0.0.1:8080/health/ready
SMOKE_PASSWORD='操作员密码' node ops/smoke-test.mjs
```

如果只做恢复验证，建议使用独立 Compose 项目名和独立数据卷，避免覆盖生产环境。

## 5. 灾难恢复顺序

1. 准备同一版本或更高版本的源码。
2. 创建新的空 PostgreSQL 卷和附件卷。
3. 启动 PostgreSQL。
4. 恢复数据库和附件。
5. 启动 API，确认迁移和 readiness。
6. 启动 Web。
7. 检查材料、批次、库存流水、项目和附件。
8. 记录恢复耗时和异常。
