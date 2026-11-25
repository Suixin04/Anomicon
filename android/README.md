# 格异录 · Android 原生客户端

Android 客户端采用 Kotlin、Jetpack Compose 和 Material 3 Expressive。功能与协议基线为 `main@1a26470` 的 HarmonyOS 7.0 v1.2.11。

## 构建

使用 JDK 17、Android SDK 36 和仓库内的 Gradle Wrapper。

```sh
./gradlew testDebugUnitTest lintDebug assembleDebug
```

应用包名为 `com.suixin.anomicon`，最低支持 Android 8.0。默认 versionCode 2 用于从本地旧版 1 验证升级。发行时以 Play Console 已用最大值为准，通过 `-PversionCode=N` 指定。构建 AAB 需要 `ANOMICON_UPLOAD_KEYSTORE`、`ANOMICON_UPLOAD_STORE_PASSWORD`、`ANOMICON_UPLOAD_KEY_ALIAS` 与 `ANOMICON_UPLOAD_KEY_PASSWORD`。

## 第一阶段验证

| 验证 | 结果 |
|---|---|
| 数据与升级 | Android 13 保留旧数据覆盖安装。Room 中有 2 条资料、230 个缓存索引。API 36 独立测试覆盖旧格式离线正文和图片、重复启动及设置保留。|
| 在线阅读 | Android 13 从 Wiki 加载 SCP-002 图文并打开原版网页。独立 WebView 测试通过本地 HTML 验证宽表横滑、同页锚点、跨条目进入原生阅读器和返回先前网页。API 33 验证从屏幕边缘滑动，API 36 验证系统 BACK。|
| 三维与布局 | Android 13 验证手机与 1200 dp 宽屏双栏，实际渲染 SCP-173。全屏隐藏系统栏、应用导航及列表，返回后恢复。Android 16 的 16384 字节页模拟器也加载了模型。|
| 构建 | 7 项 JVM 测试、所有模块的 debug lint 和 debug APK 构建通过。发行包缺少上传密钥时在 checkUpload 停止。|
| 二进制 | 最终 debug APK 的 4 种 ABI 共 20 个 ELF 通过 PT_LOAD 对齐检查，APK 通过 zipalign -c -P 16。|

[设备截图与检查记录](verification/stage1/) · [在线原生阅读](verification/stage1/reader-live.png) · [宽屏双栏](verification/stage1/tablet-scene.png) · [宽屏全屏](verification/stage1/tablet-full.png)

旧 Flutter 实现在本地标签 `archive/android-flutter`（`0bd97b8`）。首次启动时，Kotlin 客户端导入旧格式数据。商店素材与[发布检查清单](store/release-checklist.md)位于 [store](store/)。

## 阅读与档案

- 从探索、图鉴、故事和终端进入阅读器。原生阅读支持脚注、页内锚点、图片缩放与保存、文末标记已读。已读记录与滚动位置独立保存。
- 在文章内保存离线副本。从终端的「离线书架」查看占用、打开副本、返回原文或删除。
- 三维馆收录 10 个档案，4 个随包内置，6 个按需下载。详情提供署名、许可与阅读入口，下载完成后校验长度、GLB 头和 SHA-256。
- 从基金会、终端、设置或文章进入 RAISA 工单。表单提示公开发布范围，支持选填附件与诊断、本地回执和失败重试。
