# WeWe RSS "全部更新"功能修复说明

## 修复日期
2025-11-09

## 发现的问题

### 🔴 严重问题1：只更新部分公众号就停止
**现象**：点击"全部更新"按钮后，只更新了前20多个公众号就停止了

**根本原因**：
- 原代码在更新过程中，如果某个公众号遇到错误（账号被限流、网络超时等），会直接抛出异常
- 异常导致整个更新循环中断，后续所有公众号都不会被更新
- 没有任何错误处理机制

**影响**：
- 如果你有100个公众号，可能只更新了23个就停止
- 后面77个公众号的新文章都收不到

### 🟡 问题2：每个公众号只获取最新20篇
**现象**：即使公众号有很多新文章，每次更新也只获取最新20篇

**根本原因**：
- 代码硬编码只获取第一页（page=1）
- 每页最多返回20篇文章
- 没有提供配置选项

## 解决方案

### ✅ 修复1：添加完善的错误处理

```typescript
// 原代码（有问题）
for (const { id } of mps) {
  await this.refreshMpArticlesAndUpdateFeed(id);  // 这里出错会导致整个循环中断
}

// 新代码（已修复）
for (let i = 0; i < mps.length; i++) {
  try {
    await this.refreshMpArticlesAndUpdateFeed(id, page);
    successCount++;
  } catch (err) {
    failedCount++;
    this.logger.error(`更新失败，继续下一个`, err);
    // 关键：不抛出异常，继续处理下一个公众号
  }
}
```

**效果**：
- ✅ 即使某个公众号更新失败，也会继续更新剩余的所有公众号
- ✅ 详细记录每个公众号的更新状态
- ✅ 最后显示统计信息：总数、成功数、失败数

### ✅ 修复2：支持多页获取（环境变量控制）

新增环境变量 `REFRESH_ALL_PAGES`：

```bash
REFRESH_ALL_PAGES=1   # 默认值，每个公众号获取最新20篇
REFRESH_ALL_PAGES=3   # 每个公众号获取最新60篇
REFRESH_ALL_PAGES=5   # 每个公众号获取最新100篇
```

**效果**：
- ✅ 可根据需要配置获取的文章数量
- ✅ 智能停止：如果某一页文章数 < 20，自动停止（说明没有更多文章了）
- ✅ 每页之间有延迟，避免被限流

### ✅ 增强3：详细的日志记录

新增日志输出：

```
[LOG] refreshAllMpArticlesAndUpdateFeed: 开始更新，共 100 个公众号
[LOG] [1/100] 开始更新公众号: 人民日报 (MP_WXS_xxx)
[LOG] [1/100] 人民日报 - page=1/1
[LOG] [1/100] 人民日报 - 更新成功
[LOG] [2/100] 开始更新公众号: 新华社 (MP_WXS_yyy)
...
[ERROR] [23/100] 某公众号 - 更新失败: WeReadError429
[LOG] [24/100] 开始更新公众号: 继续下一个...
...
[LOG] 更新完成！总计: 100 个，成功: 97 个，失败: 3 个
```

**效果**：
- ✅ 清楚知道更新进度
- ✅ 知道哪些公众号更新失败了
- ✅ 方便排查问题

## 部署配置

### Zeabur 部署

在环境变量中添加：

```bash
# 基础配置
DATABASE_URL=mysql://root:password@host:3306/wewe-rss
AUTH_CODE=your_auth_code

# 推荐配置
REFRESH_ALL_PAGES=1        # 每个公众号获取最新20篇（默认）
UPDATE_DELAY_TIME=60       # 每页之间延迟60秒（默认）
```

### 如果你想获取更多文章

```bash
REFRESH_ALL_PAGES=3        # 每个公众号获取最新60篇
UPDATE_DELAY_TIME=60       # 保持60秒延迟，避免被限流
```

### 保守配置（更安全）

```bash
REFRESH_ALL_PAGES=1        # 只获取最新20篇
UPDATE_DELAY_TIME=90       # 延迟加长到90秒
```

## 性能影响

假设你有 **50 个公众号**：

### 默认配置 (REFRESH_ALL_PAGES=1)
- 每个公众号：1页 × 60秒延迟 = 1分钟
- 总耗时：50 × 1分钟 = **约50分钟**

### 激进配置 (REFRESH_ALL_PAGES=5)
- 每个公众号：5页 × 60秒延迟 = 5分钟
- 总耗时：50 × 5分钟 = **约4小时**

**建议**：
- 日常使用：`REFRESH_ALL_PAGES=1` （默认）
- 首次使用或长时间未更新：`REFRESH_ALL_PAGES=3` 或 `5`

## 修改的文件

```
README.md                            |  1 +
apps/server/.env.local.example       |  7 ++++
apps/server/src/configuration.ts     |  3 ++
apps/server/src/trpc/trpc.service.ts | 76 ++++++++++++++++++++++++++++-----
```

核心修改：`apps/server/src/trpc/trpc.service.ts` 的 `refreshAllMpArticlesAndUpdateFeed()` 方法

## 验证方法

部署后，查看服务器日志：

```bash
# Docker 查看日志
docker logs -f wewe-rss

# 应该看到类似输出
[LOG] refreshAllMpArticlesAndUpdateFeed: 开始更新，共 X 个公众号
[LOG] [1/X] 开始更新公众号: xxx
...
[LOG] 更新完成！总计: X 个，成功: Y 个，失败: Z 个
```

如果看到：
- ✅ "更新完成！总计: 100 个" - 说明所有公众号都被处理了
- ✅ "成功: 97 个，失败: 3 个" - 即使有失败也会继续

## 总结

这次修复解决了两个严重问题：

1. **确保所有公众号都被更新** - 即使部分失败也不影响其他公众号
2. **支持获取更多文章** - 通过环境变量灵活配置

现在你可以放心地点击"全部更新"按钮，所有订阅的公众号都会被处理！
