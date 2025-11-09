<div align="center">
<img src="https://raw.githubusercontent.com/cooderl/wewe-rss/main/assets/logo.png" width="80" alt="预览"/>

# [WeWe RSS](https://github.com/cooderl/wewe-rss)

更优雅的微信公众号订阅方式。

![主界面](https://raw.githubusercontent.com/cooderl/wewe-rss/main/assets/preview1.png)
</div>

## ✨ 功能

- v2.x版本使用全新接口，更加稳定
- 支持微信公众号订阅（基于微信读书）
- 获取公众号历史发布文章
- 后台自动定时更新内容
- 微信公众号RSS生成（支持`.atom`、`.rss`、`.json`格式)
- 支持全文内容输出，让阅读无障碍
- 所有订阅源导出OPML

### 高级功能

- **标题过滤**：支持通过`/feeds/all.(json|rss|atom)`接口和`/feeds/:feed`对标题进行过滤
  ```
  {{ORIGIN_URL}}/feeds/all.atom?title_include=张三
  {{ORIGIN_URL}}/feeds/MP_WXS_123.json?limit=30&title_include=张三|李四|王五&title_exclude=张三丰|赵六
  ```

- **手动更新**：支持通过`/feeds/:feed`接口触发单个feedid更新
  ```
  {{ORIGIN_URL}}/feeds/MP_WXS_123.rss?update=true
  ```

## 🚀 部署

### 一键部署

- [Deploy on Zeabur](https://zeabur.com/templates/DI9BBD)
- [Railway](https://railway.app/)
- [Hugging Face部署参考](https://github.com/cooderl/wewe-rss/issues/32)

### Docker Compose 部署

参考:
- [docker-compose.yml](https://github.com/cooderl/wewe-rss/blob/main/docker-compose.yml) - MySQL（推荐）
- [docker-compose.postgresql.yml](https://github.com/cooderl/wewe-rss/blob/main/docker-compose.postgresql.yml) - PostgreSQL
- [docker-compose.sqlite.yml](https://github.com/cooderl/wewe-rss/blob/main/docker-compose.sqlite.yml) - SQLite（不推荐）

### Docker 命令启动

#### MySQL (推荐)

1. 创建docker网络
   ```sh
   docker network create wewe-rss
   ```

2. 启动 MySQL 数据库
   ```sh
   docker run -d \
     --name db \
     -e MYSQL_ROOT_PASSWORD=123456 \
     -e TZ='Asia/Shanghai' \
     -e MYSQL_DATABASE='wewe-rss' \
     -v db_data:/var/lib/mysql \
     --network wewe-rss \
     mysql:8.3.0 --mysql-native-password=ON
   ```

3. 启动 Server
   ```sh
   docker run -d \
     --name wewe-rss \
     -p 4000:4000 \
     -e DATABASE_URL='mysql://root:123456@db:3306/wewe-rss?schema=public&connect_timeout=30&pool_timeout=30&socket_timeout=30' \
     -e AUTH_CODE=123567 \
     --network wewe-rss \
     cooderl/wewe-rss:latest
   ```

[Nginx配置参考](https://raw.githubusercontent.com/cooderl/wewe-rss/main/assets/nginx.example.conf)

#### SQLite (不推荐)

```sh
docker run -d \
  --name wewe-rss \
  -p 4000:4000 \
  -e DATABASE_TYPE=sqlite \
  -e AUTH_CODE=123567 \
  -v $(pwd)/data:/app/data \
  cooderl/wewe-rss-sqlite:latest
```

### 本地部署

使用 `pnpm install && pnpm run -r build && pnpm run start:server` 命令 (可配合 pm2 守护进程)

**详细步骤** (SQLite示例)：

```shell
# 需要提前声明环境变量,因为prisma会根据环境变量生成对应的数据库连接
export DATABASE_URL="file:../data/wewe-rss.db"
export DATABASE_TYPE="sqlite"
# 删除mysql相关文件,避免prisma生成mysql连接
rm -rf apps/server/prisma
mv apps/server/prisma-sqlite apps/server/prisma
# 生成prisma client
npx prisma generate --schema apps/server/prisma/schema.prisma
# 生成数据库表
npx prisma migrate deploy --schema apps/server/prisma/schema.prisma
# 构建并运行
pnpm run -r build
pnpm run start:server
```

## ⚙️ 环境变量

| 变量名                   | 说明                                                                    | 默认值                      |
| ------------------------ | ----------------------------------------------------------------------- | --------------------------- |
| `DATABASE_URL`           | **必填** 数据库地址<br>MySQL: `mysql://root:123456@host:3306/wewe-rss`<br>PostgreSQL: `postgresql://user:pass@host:5432/wewe-rss`<br>SQLite: `file:../data/wewe-rss.db` | -                           |
| `DATABASE_TYPE`          | 数据库类型: `mysql`(默认) / `postgresql` / `sqlite`                     | `mysql`                     |
| `AUTH_CODE`              | 服务端接口请求授权码，空字符或不设置将不启用 (`/feeds`路径不需要)       | -                           |
| `SERVER_ORIGIN_URL`      | 服务端访问地址，用于生成RSS完整路径                                     | -                           |
| `MAX_REQUEST_PER_MINUTE` | 每分钟最大请求次数                                                      | 60                          |
| `FEED_MODE`              | 输出模式，可选值 `fulltext` (会使接口响应变慢，占用更多内存)            | -                           |
| `CRON_EXPRESSION`        | 定时更新订阅源Cron表达式                                                | `35 5,17 * * *`             |
| `UPDATE_DELAY_TIME`      | 连续更新延迟时间，减少被关小黑屋                                        | `60s`                       |
| `REFRESH_ALL_PAGES`      | "全部更新"时每个公众号获取的页数（每页20篇），设置过大可能被限流       | `1`                         |
| `ENABLE_CLEAN_HTML`      | 是否开启正文html清理                                                    | `false`                     |
| `PLATFORM_URL`           | 基础服务URL                                                             | `https://weread.111965.xyz` |

> **注意**: 国内DNS解析问题可使用 `https://weread.965111.xyz` 加速访问

## 🔔 钉钉通知

进入 wewe-rss-dingtalk 目录按照 README.md 指引部署

## 📱 使用方式

1. 进入账号管理，点击添加账号，微信扫码登录微信读书账号。
  
   **注意不要勾选24小时后自动退出**
   
   <img width="400" src="./assets/preview2.png"/>


2. 进入公众号源，点击添加，通过提交微信公众号分享链接，订阅微信公众号。
   **添加频率过高容易被封控，等24小时解封**

   <img width="400" src="./assets/preview3.png"/>

## 🔑 账号状态说明

| 状态       | 说明                                                                |
| ---------- | ------------------------------------------------------------------- |
| 今日小黑屋 | 账号被封控，等一天恢复。账号正常时可通过重启服务/容器清除小黑屋记录 |
| 禁用       | 不使用该账号                                                        |
| 失效       | 账号登录状态失效，需要重新登录                                      |

## 💻 本地开发

1. 安装 nodejs 20 和 pnpm
2. 修改环境变量：
   ```
   cp ./apps/web/.env.local.example ./apps/web/.env
   cp ./apps/server/.env.local.example ./apps/server/.env
   ```
3. 执行 `pnpm install && pnpm run build:web && pnpm dev` 
   
   ⚠️ **注意：此命令仅用于本地开发，不要用于部署！**
4. 前端访问 `http://localhost:5173`，后端访问 `http://localhost:4000`

## ⚠️ 风险声明

为了确保本项目的持久运行，某些接口请求将通过 `weread.111965.xyz` 进行转发。请放心，该转发服务不会保存任何数据。

## ❤️ 赞助

如果觉得 WeWe RSS 项目对你有帮助，可以给我来一杯啤酒！

**PayPal**: [paypal.me/cooderl](https://paypal.me/cooderl)

**微信**:  
<img width="300" src="https://r2-assets.111965.xyz/donate-wechat.jpg" alt="Donate_WeChat.jpg">

## 👨‍💻 贡献者

<a href="https://github.com/cooderl/wewe-rss/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=cooderl/wewe-rss" />
</a>

## 📄 License

[MIT](https://raw.githubusercontent.com/cooderl/wewe-rss/main/LICENSE) @cooderl
