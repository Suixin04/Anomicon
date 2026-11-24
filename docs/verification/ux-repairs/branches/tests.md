# 主机缓存测试与发布门禁验证

分支 `fix/ux-tests`，提交 `70473dce7e4935ccc6d4af82b8788637f6b7f6be`，Git tree `cdaa4143340aee05a390028f2722ceac77d70eb5`。

在该提交的工作树根目录，使用已安装依赖的 DevEco Studio API 26 主机预览器运行：

```bash
node scripts/test-host.mjs catalog
node scripts/test-host.mjs
```

| 验证 | Hypium 逐例结果 | 入口退出码 |
|---|---|---|
| 基线缓存用例加上验证入口 | 图鉴 35 成功、3 条 SDK 解析异常，Hvigor 报 `BUILD SUCCESSFUL` | 1 |
| 补齐 URL 夹具，分别故意写错 200 的返回正文、304 重试的 ETag、晚到 304 取出的正文 | 图鉴 35 成功、3 条断言失败，三条报告均指向各自被更改的断言行，Hvigor 报 `BUILD SUCCESSFUL` | 1 |
| 恢复三处原断言后运行图鉴及全量测试 | 图鉴 38/38。公共 6、正文 47、探索 19、资料库 15、设置 4、终端 10，合计 **139/139** | 0 |

测试套件只给指定的 SCP-173 地址提供 SDK 解析结果，随后执行仓库的 URL 策略与缓存逻辑。发布任务在构建 HAP 前调用全量测试入口。可从主仓查阅已验证的逐文件更改：

```bash
git show 70473dce7e4935ccc6d4af82b8788637f6b7f6be -- \
  features/catalog/src/test/PreviewUrlFixture.js \
  features/catalog/src/test/ScpPageFetchLifecycle.test.ets \
  scripts/test-host.mjs .github/workflows/release.yml README.md
```
