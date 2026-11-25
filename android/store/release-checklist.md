# Google Play 发布检查表

资料以 2026-11-25 核对的集成快照 `84c871b`、平台分支 `1705d33` 和鸿蒙基线 `e3db5e9` 为依据。此处的证据用于确认配置与功能路径。最终 AAB、签名、实机结果及 Play Console 状态由发布者填写。

## 提交前由发布者确认

- [ ] 确认 Play Console 应用及所有权、开发者账号类型和创建日期、目标国家/地区和默认语言。候选包名为 `com.suixin.anomicon`，源版本号为 `1.0.0+1`，上传前按 Console 已使用的最高 `versionCode` 递增。核对 Play App Signing 与上传证书的 SHA-256 指纹，上传密钥及密码保存在仓库外。[应用版本](../pubspec.yaml) · [发布签名](../android/app/build.gradle.kts) · [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [ ] 核对 Console 显示的目标 API 要求。平台分支使用 Flutter 3.47.2 对应的 Android API 36 配置及最低 API 26。以最终 AAB 的清单为准。[Google Play 目标 API 要求](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [ ] 填写运营主体、可用支持邮箱、专用隐私请求渠道、隐私政策生效日期与稳定公开的网页 URL。发布后验证网页无需登录或地理限制，应用设置页和 Console 指向同一政策。核对服务、备份、保存和删除安排。[用户数据政策](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en) · [隐私政策草稿](privacy-policy-zh-CN.draft.md) · [Data safety 底稿](data-safety.md)
- [ ] 核对 RAISA 生产域名的运营权限、TLS、目标公开 Issue 仓库、GitHub App 权限和私钥存放、附件配额及公开访问方式、日志保存期、故障重试和删除工单及附件的责任人。取测试中转和独立测试仓库验证上传、去重、413/429、诊断关闭和删除流程。使用测试数据，确认发布版工单界面明确说明公开范围。客户端在工单源码中配置中转 URL，替换测试地址时同步核对回执域名与仓库校验。[工单客户端](../lib/src/raisa.dart)
- [ ] 确认所有随包、动态展示和商店素材的适用许可与归因，归档逐项清单。按真实可访问的恐怖和暴力内容填写 IARC 内容评级、目标年龄和受众、广告、数据安全及 App access 声明。审核说明可写“无需登录即可浏览，浏览网络档案需要网络，RAISA 工单为可选功能且提交后公开”，并附可执行的内容入口。[内容署名](credits.md) · [Play 应用内容要求](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en)

## 商店资料

- [ ] 粘贴并预览中文应用名、简短说明与完整说明，按 30、80、4,000 字符上限检查。核对开发者展示名、支持邮箱、类别、地区和非官方定位。[中文文案](listing-zh-CN.md) · [创建和设置应用](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en)
- [ ] 准备 512 × 512、32 位 PNG（带 Alpha 通道）的商店图标，文件至多 1,024 KB。已核对候选图标为 512 × 512、30,957 字节的 RGBA PNG（32 位）。准备 1,024 × 500 的特色图片和至少两张实际应用截图。按选定设备类型复核各自的尺寸要求。优先截取探索、图鉴、阅读、离线书架、三维和大屏画面，保留可读的原始界面并避开真实工单及未授权素材。[商店素材规范](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en) · [现有图标](app-icon.png)

## 候选包和审核流程

- [ ] 在集成工作树对候选提交运行 `flutter analyze`、`flutter test`、`flutter build apk --debug` 和 `flutter build appbundle --release`，记录提交、构建命令、输出路径、包名、版本、目标 API、ABI 和 SHA-256。Platform 分支要求提供 `ANOMICON_UPLOAD_KEYSTORE`、`ANOMICON_UPLOAD_STORE_PASSWORD`、`ANOMICON_UPLOAD_KEY_ALIAS`、`ANOMICON_UPLOAD_KEY_PASSWORD`，缺失时发布构建应失败。仅记录上传证书的公开指纹。[发布签名配置](../android/app/build.gradle.kts)
- [ ] 用 `jarsigner -verify` 核验 AAB 完整性，并用 `keytool -printcert -jarfile` 对照 Console 上传证书。用 `bundletool validate --bundle=...`、`bundletool dump manifest --bundle=... --module=base` 和 `bundletool dump config --bundle=...` 核对清单与 `PAGE_ALIGNMENT_16K`。从 AAB 生成 APK，检查 `zipalign -v -c -P 16 4 APK_PATH` 并检查所有 64 位原生库的 ELF LOAD 对齐。记录 `adb shell getconf PAGE_SIZE` 返回 `16384` 的真机或模拟器验证结果。[Android 16 KB 页支持](https://developer.android.com/guide/practices/page-sizes)
- [ ] 在窄屏、大屏与 API 36 设备上安装候选包，验证探索或搜索打开正文、原生与网页切换、脚注返回、断网读离线副本、正文与三维双向返回、内置及下载后离线渲染、旋转全屏、暂停续传与校验失败、工单测试、浅深主题和系统返回。收集带环境和版本的验收结果，复核 WebView、合并清单权限与明文网络配置。[Android 清单](../android/app/src/main/AndroidManifest.xml)
- [ ] 按账号适用条件走内部、封闭或生产轨道。若为 2023-11-13 后创建的个人开发者账号，先满足至少 12 位测试人员连续加入封测 14 天并申请生产权限。在 Console 看预发布报告和政策审查状态，再由账号所有者决定提交和发布。[个人账号封测要求](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
