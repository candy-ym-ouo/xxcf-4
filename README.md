# 旧物维修履历 Repair Log

面向家庭收藏与日常使用的旧物数字档案 MVP。当前版本包含 React + TypeScript + Vite 前端和 Fastify API，使用本地 JSON 仓储即可一键运行，后续可以平滑替换为 PostgreSQL/Prisma。

## 运行

```bash
npm install
npm run dev:full
```

打开 `http://localhost:5173/`，API 默认运行在 `http://localhost:8787/`。也可以分别运行 `npm run api` 和 `npm run dev`。

首次启动会创建 `server/data.json`，演示账号为 `linmo@example.com` / `repair-log-demo`。生产环境请通过 `REPAIR_LOG_JWT_SECRET` 设置 JWT 密钥。

## 已实现

- 物件档案网格、关键词搜索、类别筛选（可与 API 同步）
- 物件详情与维修履历时间线
- 新建物件、新增维修履历、草稿状态
- 维修前后照片对比滑块（照片墙页签）
- 提醒中心：完成并记录、待处理/已完成分组
- 家庭成员、邀请码、角色展示
- 通知偏好与 JSON/PDF 导出入口
- 移动端响应式布局
- Fastify API：JWT access/refresh Cookie、家庭空间与角色权限
- 物件/损坏部位/履历/步骤/材料/附件/提醒/通知/审计日志 CRUD
- 附件预签名流程（本地上传目录模拟对象存储）与 20MB 限制
- 到期提醒扫描、完成提醒自动生成保养履历
- 单物件 JSON 导出

后续接入 Fastify/Prisma API 时，可将 `src/main.tsx` 中的示例数据和操作函数替换为 TanStack Query 数据层。
