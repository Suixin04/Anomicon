# Google Play Data safety 填报底稿

以最终发布 AAB 和实际服务配置填写。源码证据来自 `84c871b` 集成快照以及 `1705d33` 平台分支。输入字段和目的可从客户端确认，线上保留时长、代理日志及第三方处理范围由发布者以部署证据补齐。[Play Data safety 指南](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en) · [用户数据政策](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)

| 流向 | 观察到的数据与用途 | 拟核对的 Play 字段及填法 |
| --- | --- | --- |
| 设备本地 | 设置、搜索和阅读历史、收藏、进度、考核、离线内容、模型与工单回执。用于本机恢复和展示。 | 单纯本地处理通常超出表单的采集范围。核对最终清单的备份和迁移规则，以及任何 SDK 上传。 |
| Wiki 与媒体 | 目录与正文请求、图片地址、网页模式的页面及子资源。远端可见 IP、请求路径及常规网络信息。网页也可能处理 Cookie。 | 核对是否记录访问路径、交互或可识别信息，按实际行为评估“网页浏览记录”“应用活动”和相关标识。区分用户浏览开放网络页面和应用控制的接口或派生请求。按官方 WebView 规则判断。 |
| 三维资源 | GitHub Raw 的版本固定下载地址、模型路径及网络连接信息。下载结果保存在设备上。查看器通过 `127.0.0.1` 提供模型与脚本。 | 核对 GitHub 等资源提供方日志、请求字段及查看器运行时的外联网行为。设备环回不涉及向外发送。 |
| RAISA 工单文本 | 类别、简述、说明、可选联络代号。发送给中转用于创建公开 Issue。 | 至少核对“其他用户生成内容”。联络代号可由用户填入邮箱、用户名等，核对“个人信息”下对应细类。工单可选，填报目的以应用功能、支持或与用户沟通的实际用途为准。 |
| RAISA 附件 | 用户选定的图片、PDF 和受支持文本文件。中转保留文件并在公开 Issue 写入访问链接。附件可能包含截图、作者名或文件元数据。 | 核对“照片”和“文件与文档”，并核对传输给公开链接访问方的共享义务。 |
| RAISA 诊断与防重复 | 应用版本、系统、窗口宽度、主题和可选条目上下文。请求另带去重标识，中转按 IP 限流。诊断可关闭，版本始终随工单发送。 | 核对“诊断信息”和“设备或其他 ID”的适用性。确认去重标识保存期、IP 是否写入日志或仅短时用于限流，以及诊断内容是否包含可推知的浏览活动。 |

- 以实际数据类型逐项判断采集、共享、是否可选和用途。公开工单必须在应用内清楚说明公开范围。若考虑采用 Google 的用户主动分享例外，须核对最终确认流程、用户的合理预期及公开附件行为，并保留判定依据。表单中的“共享”口径与隐私政策披露范围并非同一项。
- “传输加密”需核对最终 APK 实际发出的第一方与 SDK 数据请求。包括网页资源、资源重定向和工单。用已核准的测试环境验证，并检查 Android 合并清单限制明文访问的规则。源码中的 HTTPS 工单地址和环回配置不能独自证明全部传输。
- 发布者提供实际可用的数据删除入口与处理流程，覆盖公开 Issue、托管附件以及可控的存储和日志。清空本地存储和关闭 Issue 不会自动删除公开内容。当前客户端无需创建账号，若后续增加账号则重新核对账号删除要求。[Play 账号删除要求](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)
- 按交付版本、地区和各非内部发布轨道重新核对依赖、SDK 和网络端点，使用 Play Console 实际问卷用词。先验证政策公开地址和应用设置入口，再确认数据安全表。[Play Data safety 指南](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)

## 源码核对索引

发布分支集成后从以下入口复核。线上环境证据应补充 TLS 终止、反向代理日志、GitHub App 和目标仓库、附件读写及清除流程。当前资料未确认线上部署和隐私请求联系人。

- 工单入参、回执与传输。[raisa.dart](../lib/src/raisa.dart#L103) · [raisa_page.dart](../lib/src/raisa_page.dart#L25)
- 工单格式、公开附件和 IP 限流。鸿蒙基线 `e3db5e9` 的 `tools/raisa-relay/server.mjs` 与 `tools/raisa-relay/README.md` 记录服务实现及部署参数。可在该提交用 `git show e3db5e9:tools/raisa-relay/README.md` 查看。
- 阅读与持久化。[阅读页](../lib/src/article_page.dart) · [本地状态](../lib/src/local_store.dart) · [离线书架存储](../lib/src/offline_article_store.dart)
- 模型与网络。[模型清单](../lib/src/seed_data.dart) · [模型下载](../lib/src/archive_download.dart) · [Android 清单](../android/app/src/main/AndroidManifest.xml)
