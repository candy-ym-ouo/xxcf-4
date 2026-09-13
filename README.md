# 手工艺材料追踪器

面向染布、木工、陶艺和金工爱好者的真实库存与项目材料追踪系统。

系统记录材料来源、批次、颜色变化、剩余数量、项目计划用料和实际消耗。前端使用 Vue 3，后端使用 Node.js + Fastify，业务数据保存在 PostgreSQL。项目不提供演示模式，不预置虚假材料、项目或统计数字。

## 已实现能力

- 首次初始化、单操作员登录和密码修改。
- 来源与存放位置管理。
- 材料档案、工艺类型、单位、低库存阈值和颜色档案。
- 批次入库、来源追溯、有效期和库存流水。
- 库存调整、自动耗尽、归档和并发余额保护。
- 项目、材料需求、计划与实际消耗对比。
- 消耗、损耗、撤销和反向库存流水。
- 颜色变化时间线和批次当前颜色。
- 材料、批次、来源、颜色、库存状态和位置搜索筛选。
- 受保护图片附件。
- CSV、完整工作区 JSON 导出。
- 仪表盘、审计日志、健康检查、备份和恢复脚本。
- PostgreSQL、附件卷和 Docker Compose 持久化。

## 技术栈

| 层 | 技术 |
| --- | --- |
| Web | Vue 3、TypeScript、Vite、Pinia、Vue Router、Element Plus |
| API | Node.js 22、TypeScript、Fastify、Zod |
| 数据库 | PostgreSQL 16、SQL migrations、不可变库存流水 |
| 鉴权 | Argon2id、HttpOnly 会话 Cookie |
| 部署 | Docker Compose、Nginx |
| 测试 | Vitest、API smoke test、生产构建检查 |

## 目录

```text
origin/
├── apps/
│   ├── api/                 Node.js API、SQL migrations、测试
│   └── web/                 Vue 3 前端
├── packages/
│   └── contracts/           前后端共享枚举、校验和单位换算
├── ops/
│   ├── backup.sh
│   ├── restore.sh
│   ├── healthcheck.sh
│   └── smoke-test.mjs
├── docs/
│   ├── deployment.md
│   ├── backup-restore.md
│   └── api.md
├── docker-compose.yml
└── .env.example
```

## 快速启动

要求：

- Docker 和 Docker Compose。
- 默认 Web 端口 `8080`，API 端口 `3000`，PostgreSQL 端口 `55432`。
- 生产环境需要设置强密码和至少 32 字符的 `SESSION_SECRET`。

```bash
cd origin
cp .env.example .env
# 修改 .env 中的 POSTGRES_PASSWORD 和 SESSION_SECRET
docker compose -p handcraft-material-tracker up -d --build
```

打开：

```text
http://localhost:8080
```

生成安全密钥：

```bash
openssl rand -hex 32
```

首次打开会进入初始化页面。系统只创建一个操作员，不提供公开注册。初始化完成前数据库中没有业务数据。

如果本机 `8080` 已被占用，可在 `.env` 中修改 `WEB_PORT`。

## 常用命令

```bash
# 查看服务
docker compose -p handcraft-material-tracker ps

# 查看日志
docker compose -p handcraft-material-tracker logs -f api

# 健康检查
./ops/healthcheck.sh

# 停止服务，保留数据卷
docker compose -p handcraft-material-tracker down

# 启动服务
docker compose -p handcraft-material-tracker up -d
```

不要执行 `docker compose down -v`，除非确认要永久删除数据库和附件。

## 本地开发

要求 Node.js 22+ 和 pnpm 10。

```bash
cd origin
pnpm install
cp .env.example .env
docker compose -p handcraft-material-tracker up -d postgres
pnpm db:migrate
pnpm dev
```

开发地址：

- Web：`http://localhost:5173`
- API：`http://localhost:3000`
- PostgreSQL：`127.0.0.1:55432`

`.env` 会被 API 自动加载，Web 的 Vite 代理会把 `/api` 转发到本地 API。

## 测试与构建

```bash
pnpm typecheck
pnpm test
pnpm build
```

对已初始化的运行环境执行完整 API 验收链：

```bash
SMOKE_BASE_URL=http://127.0.0.1:8080 \
SMOKE_PASSWORD='你的操作员密码' \
node ops/smoke-test.mjs
```

验收脚本会真实创建来源、材料、批次、项目、需求、消耗和颜色变化，验证余额从 1000g 降到 500g、撤销后恢复 1000g、最新流水为 `REVERSAL`、颜色和搜索正确。

建议只在专用验收数据库执行该脚本，因为它会留下测试业务数据。

## 业务一致性

- 批次是库存的最小核算单位，材料列表只做聚合。
- 创建批次和首条 `OPENING` 流水在同一事务完成。
- 消耗、调整和撤销都在事务中锁定批次。
- 批次余额绝不允许小于 0。
- 消耗记录保存实际使用量和损耗量，总扣减量等于两者之和。
- 撤销不删除历史，而是新增 `REVERSAL` 流水。
- 颜色变化更新当前颜色快照，但不自动修改库存。
- 计划用料不扣库存，实际消耗才扣库存。
- 数量使用 PostgreSQL `numeric(18,6)`，API 使用十进制字符串。
- 归档代替核心数据硬删除。
- 审计日志只追加，不更新、不删除。

## 部署

生产使用 Nginx 同源提供前端和 `/api` 反向代理。数据库和 API 不在公网直接暴露。HTTPS 建议由外部反向代理或负载均衡器终止。

详细说明见：

- [部署文档](docs/deployment.md)
- [备份与恢复](docs/backup-restore.md)
- [API 文档](docs/api.md)

## 数据安全

- 修改 `.env.example` 中的默认数据库密码。
- 使用 `openssl rand -hex 32` 生成 `SESSION_SECRET`。
- 生产环境设置 `COOKIE_SECURE=true` 并使用 HTTPS。
- 定期执行 `ops/backup.sh` 并验证 `ops/restore.sh`。
- 不要将 `.env`、备份文件或上传目录提交到版本控制。
