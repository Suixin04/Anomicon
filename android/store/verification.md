# Android 候选版验证

候选 APK 和 AAB 对应源码 `27d6b51`。后续商店资料提交只修改 `android/store`。版本 `1.0.0`，versionCode `1`，包名 `com.suixin.anomicon`，最低 API 26，目标和编译 API 36。

- Flutter 3.47.2 静态分析通过，36 项测试通过。独立复核涵盖导航返回、已读同步、弱网链接直达、脚注、离线副本和模拟 RAISA 工单。
- 正式模式 AAB 可构建。缺上传签名的发布构建会被拒绝。用本地临时证书签出的 AAB 通过签名完整性、证书指纹和 Bundletool 1.18.1 验证。由它生成的通用 APK 使用本机调试证书，可直接安装。
- AAB 的配置为 `PAGE_ALIGNMENT_16K`。通用 APK 通过 `zipalign -c -P 16 4`。ARM64 和 x86-64 各四个 ELF 库的 `PT_LOAD` 对齐均至少 16 KiB。Android 16 模拟器实测 `PAGE_SIZE=16384`，成功安装、启动并阅读。
- Android 13 模拟器打开 SCP-6551 的 Wiki 原版网页。系统文件选择器读取了 25 字节测试附件，RAISA 诊断显示安装包版本 `1.0.0`。工单 UI 采用本地测试数据，模拟中转用于提交流程。
- Android 13 模拟器渲染内置 SCP-173，进入全屏并用系统返回键恢复原详情。此前同时挂载两个 WebView 时模拟器进程退出，修复后通过。SCP-650 真实下载并打开。
- Android 16 模拟器从图鉴加载 SCP-002。保存后关闭 Wi-Fi 和移动数据，强制停止应用并重启。从离线书架重新打开时显示永久离线副本、正文和图片。

| 产物 | SHA-256 |
| --- | --- |
| `anomicon-local-test.apk` | `fe91663ebf2a3fdeb6374c89dc658aa7a0fc38530aed767c530a5aa91c3a8dd7` |
| `anomicon-test-signed.aab` | `5c9092aad60477fc85287af7315c353b82f059121726af266420e8f1f4102bd6` |

设备验证来自模拟器。其他厂商设备及 Play 预发布报告待确认。生产发布需由账号所有者核对现有版本号和上传证书，提供正式签名配置及公开隐私政策，确认三维资产逐件授权并填写 Play Console 声明。详见 [发布检查表](release-checklist.md)。
