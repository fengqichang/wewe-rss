# "全部更新"功能增强说明

## 问题描述

在原版代码中发现两个严重问题：

### 问题1：只更新部分公众号
当"全部更新"过程中某个公众号更新失败（例如账号被限流、网络错误等），整个更新流程会立即中断，导致后续的公众号都没有被更新。例如：
- 用户有 100 个公众号订阅
- 更新到第 23 个公众号时遇到错误
- 后面 77 个公众号都不会被更新

### 问题2：每个公众号只获取第一页
每个公众号只会获取最新的 **20 篇文章**（第一页），无法获取更多历史文章。

## 解决方案

1. **添加错误处理**：即使某个公众号更新失败，也会继续更新下一个公众号，确保所有公众号都被处理
2. **添加环境变量 `REFRESH_ALL_PAGES`**：允许用户自定义每个公众号获取的页数
3. **详细的日志记录**：显示更新进度、成功/失败统计，方便排查问题

## 修改内容

### 1. 新增环境变量

**环境变量名**: `REFRESH_ALL_PAGES`

**默认值**: `1` (保持原有行为，只获取第一页)

**说明**: 控制"全部更新"时每个公众号获取的页数
- 每页固定返回 20 篇文章
- 设置为 `1`: 获取最新 20 篇
- 设置为 `3`: 获取最新 60 篇
- 设置为 `5`: 获取最新 100 篇
- 以此类推...

**注意**: 设置过大可能导致请求过于频繁而被微信读书限流，建议不要超过 10

### 2. 代码修改文件

1. **`apps/server/src/configuration.ts`** (第20行)
   - 添加环境变量读取逻辑

2. **`apps/server/src/trpc/trpc.service.ts`** (第35, 48, 302-377行)
   - 添加 `refreshAllPages` 属性
   - **重构 `refreshAllMpArticlesAndUpdateFeed()` 方法**：
     - ✅ **添加 try-catch 错误处理**：每个公众号单独处理，失败不影响其他公众号
     - ✅ **支持多页获取**：根据 `REFRESH_ALL_PAGES` 环境变量控制
     - ✅ **智能停止机制**：当某一页返回的文章数 < 20 时自动停止
     - ✅ **详细日志记录**：显示总数、当前进度、公众号名称、成功/失败统计

3. **`apps/server/.env.local.example`** (第33-38行)
   - 添加示例配置和注释

4. **`README.md`** (第126行)
   - 在环境变量说明表格中添加新变量的说明

## 使用方法

### 部署到 Zeabur

在 Zeabur 的环境变量设置中添加：

```
REFRESH_ALL_PAGES=5
```

这将使"全部更新"时每个公众号获取最新 100 篇文章（5页 × 20篇/页）。

### Docker 部署

在 docker run 命令中添加环境变量：

```bash
docker run -d \
  --name wewe-rss \
  -p 4000:4000 \
  -e DATABASE_URL='...' \
  -e AUTH_CODE=123567 \
  -e REFRESH_ALL_PAGES=5 \
  --network wewe-rss \
  cooderl/wewe-rss:latest
```

### Docker Compose 部署

在 `docker-compose.yml` 中添加环境变量：

```yaml
services:
  server:
    image: cooderl/wewe-rss:latest
    environment:
      - DATABASE_URL=mysql://root:123456@db:3306/wewe-rss
      - AUTH_CODE=123567
      - REFRESH_ALL_PAGES=5  # 添加这一行
```

## 工作原理

### 原有逻辑（有严重问题！）

```typescript
for (const { id } of mps) {
  // ❌ 问题1: 没有错误处理，某个公众号失败会导致整个循环中断
  await this.refreshMpArticlesAndUpdateFeed(id);  // ❌ 问题2: 只获取第一页
}
```

### 新逻辑（已修复）

```typescript
for (let i = 0; i < mps.length; i++) {
  const { id, mpName } = mps[i];

  try {
    // ✅ 循环获取多页，由 REFRESH_ALL_PAGES 控制
    for (let page = 1; page <= this.refreshAllPages; page++) {
      const { hasHistory } = await this.refreshMpArticlesAndUpdateFeed(id, page);

      // ✅ 智能停止：如果当前页返回的文章数 < 20，说明没有更多文章了
      if (hasHistory === 0) {
        break;
      }

      // 每页之间延迟
      if (page < this.refreshAllPages) {
        await new Promise(resolve => setTimeout(resolve, this.updateDelayTime * 1000));
      }
    }

    successCount++;
    this.logger.log(`[${i + 1}/${mps.length}] ${mpName} - 更新成功`);

  } catch (err) {
    // ✅ 关键修复：捕获错误但继续处理下一个公众号
    failedCount++;
    this.logger.error(`[${i + 1}/${mps.length}] ${mpName} - 更新失败:`, err);
    // 不抛出异常，继续下一个公众号
  }
}

// ✅ 最后显示统计信息
this.logger.log(`更新完成！总计: ${mps.length} 个，成功: ${successCount} 个，失败: ${failedCount} 个`);
```

## 性能考虑

### 时间成本

假设你有 10 个公众号订阅，`REFRESH_ALL_PAGES=5`，`UPDATE_DELAY_TIME=60`：

- 每个公众号获取 5 页，每页之间延迟 60 秒
- 单个公众号耗时：5 页 × 60 秒 = 300 秒 (5 分钟)
- 10 个公众号总耗时：10 × 5 分钟 = 50 分钟

### 限流风险

- **建议设置**: `REFRESH_ALL_PAGES=3` ~ `5` (60-100篇文章)
- **保守设置**: `REFRESH_ALL_PAGES=1` ~ `2` (20-40篇文章)
- **激进设置**: `REFRESH_ALL_PAGES=10` (200篇文章，可能被限流)

### 延迟时间调整

可以配合 `UPDATE_DELAY_TIME` 环境变量使用：

```bash
# 较快的更新速度（有被限流的风险）
UPDATE_DELAY_TIME=30
REFRESH_ALL_PAGES=3

# 较慢的更新速度（更安全）
UPDATE_DELAY_TIME=90
REFRESH_ALL_PAGES=5
```

## 智能优化

新代码包含以下智能优化：

1. **自动停止**: 当某一页返回的文章数 < 20 时，认为已经获取完所有文章，自动停止
2. **日志记录**: 每次获取都会记录当前进度，方便调试
3. **向后兼容**: 默认值为 1，不影响现有用户的使用

## 其他说明

- **定时任务**: 自动定时更新（由 `CRON_EXPRESSION` 控制）仍然只获取每个公众号的最新 20 篇文章，以减少 API 调用
- **单个更新**: 在网页上点击单个公众号的"更新"按钮仍然只获取最新 20 篇
- **获取历史文章**: 如需获取某个公众号的全部历史文章，请使用"获取历史文章"功能（会持续分页获取直到获取完所有文章）

## 修改者

这次修改是为了解决"全部更新"按钮更新文章数量受限的问题，使用户可以通过环境变量灵活配置更新行为。
