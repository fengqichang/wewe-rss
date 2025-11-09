# PostgreSQL 支持说明

本项目现已支持 PostgreSQL 数据库。

## 🎯 支持的数据库

- ✅ **MySQL** (默认推荐)
- ✅ **PostgreSQL** (新增支持)
- ✅ **SQLite** (仅适合测试)

## 🚀 使用 PostgreSQL 部署

### 方式1：在 Zeabur 部署

#### 步骤1：添加 PostgreSQL 服务

1. 在 Zeabur 项目中点击 **"Create Service"**
2. 选择 **"Prebuilt"** → **"PostgreSQL"**
3. 等待 PostgreSQL 服务创建完成

#### 步骤2：配置环境变量

在 wewe-rss 服务中添加环境变量：

```bash
# 使用 Zeabur 提供的变量（推荐）
DATABASE_URL=${POSTGRES_URL}
DATABASE_TYPE=postgresql

# 其他必需配置
AUTH_CODE=your_password
SERVER_ORIGIN_URL=${ZEABUR_URL}

# 可选配置
REFRESH_ALL_PAGES=1
UPDATE_DELAY_TIME=60
FEED_MODE=fulltext
```

#### 步骤3：重启服务

保存环境变量后，Zeabur 会自动重启服务。

---

### 方式2：Docker Compose 部署

使用提供的 `docker-compose.postgresql.yml`：

```bash
# 启动服务
docker-compose -f docker-compose.postgresql.yml up -d

# 查看日志
docker-compose -f docker-compose.postgresql.yml logs -f

# 停止服务
docker-compose -f docker-compose.postgresql.yml down
```

配置文件内容：

```yaml
version: '3.9'

services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: wewerss
      POSTGRES_PASSWORD: wewerss_password
      POSTGRES_DB: wewerss
    volumes:
      - postgres_data:/var/lib/postgresql/data

  app:
    image: cooderl/wewe-rss-postgresql:latest
    ports:
      - 4000:4000
    environment:
      - DATABASE_URL=postgresql://wewerss:wewerss_password@db:5432/wewerss?schema=public
      - DATABASE_TYPE=postgresql
      - AUTH_CODE=123567
      - REFRESH_ALL_PAGES=1
    depends_on:
      - db

volumes:
  postgres_data:
```

---

### 方式3：Docker 命令启动

#### 1. 创建 Docker 网络

```bash
docker network create wewe-rss
```

#### 2. 启动 PostgreSQL

```bash
docker run -d \
  --name postgres \
  -e POSTGRES_USER=wewerss \
  -e POSTGRES_PASSWORD=wewerss_password \
  -e POSTGRES_DB=wewerss \
  -v postgres_data:/var/lib/postgresql/data \
  --network wewe-rss \
  postgres:16-alpine
```

#### 3. 启动 WeWe RSS

```bash
docker run -d \
  --name wewe-rss \
  -p 4000:4000 \
  -e DATABASE_URL='postgresql://wewerss:wewerss_password@postgres:5432/wewerss?schema=public' \
  -e DATABASE_TYPE=postgresql \
  -e AUTH_CODE=123567 \
  -e REFRESH_ALL_PAGES=1 \
  --network wewe-rss \
  cooderl/wewe-rss-postgresql:latest
```

---

## 📝 环境变量配置

### 必填环境变量

```bash
# PostgreSQL 连接字符串
DATABASE_URL=postgresql://user:password@host:5432/database?schema=public

# 指定数据库类型
DATABASE_TYPE=postgresql

# 授权码
AUTH_CODE=your_password
```

### PostgreSQL 连接字符串格式

```
postgresql://用户名:密码@主机:端口/数据库名?schema=public
```

示例：
```bash
# 本地开发
DATABASE_URL=postgresql://wewerss:wewerss_password@localhost:5432/wewerss?schema=public

# Docker 内部
DATABASE_URL=postgresql://wewerss:wewerss_password@postgres:5432/wewerss?schema=public

# Zeabur
DATABASE_URL=${POSTGRES_URL}
```

### 可选环境变量

```bash
# 服务器访问地址
SERVER_ORIGIN_URL=https://your-domain.com

# 全部更新时每个公众号获取的页数
REFRESH_ALL_PAGES=1

# 连续更新延迟时间（秒）
UPDATE_DELAY_TIME=60

# 全文模式
FEED_MODE=fulltext

# 定时更新表达式
CRON_EXPRESSION=35 5,17 * * *
```

---

## 🔧 数据库迁移

### 首次部署

首次部署时，Prisma 会自动运行数据库迁移，创建必要的表结构。

如果需要手动运行迁移：

```bash
# 进入容器
docker exec -it wewe-rss sh

# 运行迁移
npx prisma migrate deploy
```

### 从其他数据库迁移

如果你之前使用 MySQL 或 SQLite，需要导出数据后重新导入：

#### 1. 导出数据（以 MySQL 为例）

```bash
# 导出数据
mysqldump -u root -p wewe-rss > backup.sql
```

#### 2. 转换并导入到 PostgreSQL

由于数据库语法差异，可能需要手动调整 SQL 语句，或使用专门的迁移工具如 `pgloader`。

---

## 🐛 故障排查

### 问题1：连接失败

**错误**：
```
Error: Can't reach database server at `postgres:5432`
```

**解决**：
- 检查 PostgreSQL 服务是否启动
- 检查网络连接（Docker 网络配置）
- 验证连接字符串中的主机名、端口

### 问题2：认证失败

**错误**：
```
Error: Authentication failed for user 'wewerss'
```

**解决**：
- 检查用户名和密码是否正确
- 确认 PostgreSQL 用户已创建
- 检查 `pg_hba.conf` 配置（允许密码认证）

### 问题3：数据库不存在

**错误**：
```
Error: Database "wewerss" does not exist
```

**解决**：
```bash
# 连接到 PostgreSQL
docker exec -it postgres psql -U wewerss

# 创建数据库
CREATE DATABASE wewerss;
```

### 问题4：迁移失败

**错误**：
```
Error: Migration failed
```

**解决**：
```bash
# 重置迁移（⚠️ 会删除所有数据）
npx prisma migrate reset

# 或手动运行迁移
npx prisma migrate deploy
```

---

## 📊 性能对比

| 数据库       | 部署难度 | 性能  | 并发支持 | 数据持久化 | 推荐场景           |
| ------------ | -------- | ----- | -------- | ---------- | ------------------ |
| MySQL        | 中等     | 高    | 优秀     | ✅         | 生产环境（推荐）   |
| PostgreSQL   | 中等     | 高    | 优秀     | ✅         | 生产环境（推荐）   |
| SQLite       | 简单     | 中等  | 一般     | ⚠️         | 测试环境           |

---

## ✅ 验证安装

部署完成后，访问：

```
http://your-domain:4000
```

查看日志确认 PostgreSQL 连接成功：

```bash
docker logs wewe-rss
```

应该看到：

```
✅ Prisma schema loaded from prisma/schema.prisma
✅ Datasource "db": PostgreSQL database "wewerss" at "postgres:5432"
✅ Database migrations applied successfully
✅ Server started on http://0.0.0.0:4000
```

---

## 📚 相关文档

- [Prisma PostgreSQL 文档](https://www.prisma.io/docs/concepts/database-connectors/postgresql)
- [PostgreSQL 官方文档](https://www.postgresql.org/docs/)
- [Zeabur PostgreSQL 服务](https://zeabur.com/docs/marketplace/postgresql)

---

## 🆘 需要帮助？

如果遇到问题，请提供：
1. 完整的错误日志
2. 环境变量配置（隐藏敏感信息）
3. PostgreSQL 版本信息
4. 部署方式（Zeabur / Docker / 其他）
