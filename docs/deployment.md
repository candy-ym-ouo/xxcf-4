# 部署文档

## 1. 生产拓扑

```text
浏览器
  │ HTTPS
外部反向代理 / 负载均衡
  │ HTTP 80
Nginx Web 容器
  ├── Vue 静态文件
  └── /api、/health 反向代理
          │
      Fastify API
          │
      PostgreSQL 16

附件持久卷 ───── API
```

- Web 和 API 由 Docker Compose 管理。
- PostgreSQL 只在 Compose 内网和本机回环端口可见。
- API 只在 `127.0.0.1:3000` 暴露，供本地排障。
- Web 由 `WEB_PORT` 配置，默认 `8080`。
- API 启动前执行数据库迁移。
- API readiness 通过后才启动 Web。

## 2. 首次部署

```bash
cd origin
cp .env.example .env
```

至少修改：

```dotenv
POSTGRES_PASSWORD=使用高强度随机密码
SESSION_SECRET=至少32字符随机值
PUBLIC_APP_URL=https://materials.example.com
COOKIE_SECURE=true
WEB_PORT=8080
TZ=Asia/Shanghai
```

生成密钥：

```bash
openssl rand -hex 32
```

启动：

```bash
docker compose -p handcraft-material-tracker up -d --build
docker compose -p handcraft-material-tracker ps
curl -f http://127.0.0.1:8080/health/ready
```

浏览器打开 `PUBLIC_APP_URL`，完成首次初始化。

## 3. HTTPS

生产环境必须启用 HTTPS。推荐让外部 Nginx、Caddy、Traefik 或云负载均衡器终止 TLS，再转发到 Web 容器的 `8080`。

启用 HTTPS 后：

```dotenv
PUBLIC_APP_URL=https://materials.example.com
COOKIE_SECURE=true
```

`COOKIE_SECURE=true` 时不能通过普通 HTTP 登录，否则浏览器不会发送会话 Cookie。

## 4. 数据卷

Compose 创建：

- `handcraft-material-tracker_postgres_data`：数据库。
- `handcraft-material-tracker_uploads_data`：附件。

查看卷：

```bash
docker volume ls | grep handcraft-material-tracker
```

不要使用 `docker compose down -v` 做普通重启，否则会删除持久数据。

## 5. 升级

```bash
cd origin
./ops/backup.sh
git pull
docker compose -p handcraft-material-tracker build --pull
docker compose -p handcraft-material-tracker up -d
docker compose -p handcraft-material-tracker logs --tail=100 api
```

API 启动时检查迁移：

- 新迁移成功应用后进入 ready。
- 已应用的迁移文件若被修改，API 拒绝启动。
- 迁移失败时不要继续升级，先使用备份恢复或修复迁移。

## 6. 常见排障

### API 不是 healthy

```bash
docker compose -p handcraft-material-tracker logs api
docker compose -p handcraft-material-tracker logs postgres
```

检查 `.env` 中的 `POSTGRES_PASSWORD` 是否与当前 PostgreSQL 数据卷初始化时使用的密码一致。修改已有数据卷的密码不会自动变更数据库用户密码。

### Web 无法访问

```bash
docker compose -p handcraft-material-tracker ps
docker compose -p handcraft-material-tracker logs web
```

确认宿主机端口没有被占用，可以修改 `.env` 的 `WEB_PORT`。

### 登录后立刻失效

- HTTPS 环境必须设置 `COOKIE_SECURE=true`。
- HTTP 本地环境应设置 `COOKIE_SECURE=false`。
- 确认系统时间正确，避免 Cookie 提前过期。

### 附件上传失败

```bash
docker compose -p handcraft-material-tracker exec api sh -c 'touch /app/uploads/.health && rm /app/uploads/.health'
```

失败时检查上传卷权限和 `MAX_UPLOAD_BYTES`。
