# Google Play 发布检查表

本检查表适用于 Kotlin/Compose 原生项目。最终 AAB、签名、设备结果和 Play Console 状态由发布者按候选包确认。

## 提交前由发布者确认

- [ ] 确认 Play Console 应用及所有权、开发者账号类型和创建日期、目标国家/地区和默认语言。原生包名为 `com.suixin.anomicon`，当前版本名 `1.2.11`。通过 `-PversionCode=N` 指定版本号，确保高于 Console 已使用的最大值。核对 Play App Signing 和上传证书 SHA-256。将上传密钥及密码保存在仓库外。[原生构建和发布签名](../app/build.gradle.kts) · [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [ ] 核对 Console 显示的目标 API 要求。原生项目的编译和目标 API 为 36，最低 API 26。以最终 AAB 的清单为准。[Google Play 目标 API 要求](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [ ] 填写运营主体、可用支持邮箱、专用隐私请求渠道、隐私政策生效日期与稳定公开的网页 URL。发布后验证网页无需登录或地理限制，应用设置页和 Console 指向同一政策。核对服务、备份、保存和删除安排。[用户数据政策](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en) · [隐私政策草稿](privacy-policy-zh-CN.draft.md) · [Data safety 底稿](data-safety.md)
- [ ] 核对 RAISA 生产域名的运营权限、TLS、目标公开 Issue 仓库、GitHub App 权限和私钥存放、附件配额及公开访问方式、日志保存期、故障重试和删除工单及附件的责任人。取测试中转和独立测试仓库验证上传、去重、413/429、诊断关闭和删除流程。使用测试数据，确认发布版工单界面明确说明公开范围。切换生产服务时同步核对回执域名与仓库校验。[原生终端模块](../feature/terminal/)
- [ ] 确认所有随包、动态展示和商店素材的适用许可与归因，归档逐项清单。按真实可访问的恐怖和暴力内容填写 IARC 内容评级、目标年龄和受众、广告、数据安全及 App access 声明。审核说明可写“无需登录即可浏览，浏览网络档案需要网络，RAISA 工单为可选功能且提交后公开”，并附可执行的内容入口。[内容署名](credits.md) · [Play 应用内容要求](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en)

## 商店资料

- [ ] 粘贴并预览中文应用名、简短说明与完整说明，按 30、80、4,000 字符上限检查。核对开发者展示名、支持邮箱、类别、地区和非官方定位。[中文文案](listing-zh-CN.md) · [创建和设置应用](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en)
- [ ] 准备 512 × 512、32 位 PNG（带 Alpha 通道）的商店图标，文件至多 1,024 KB。已核对候选图标为 512 × 512、30,957 字节的 RGBA PNG（32 位）。准备 1,024 × 500 的特色图片和至少两张实际应用截图。按选定设备类型复核各自的尺寸要求。优先截取探索、图鉴、阅读、离线书架、三维和大屏画面，保留可读的原始界面并避开真实工单及未授权素材。[商店素材规范](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en) · [现有图标](app-icon.png)

## 候选包和审核流程

- [ ] 在原生项目目录执行 `./gradlew testDebugUnitTest lintDebug :app:assembleDebug`，随后配置 `ANOMICON_UPLOAD_KEYSTORE`、`ANOMICON_UPLOAD_STORE_PASSWORD`、`ANOMICON_UPLOAD_KEY_ALIAS` 和 `ANOMICON_UPLOAD_KEY_PASSWORD`，执行 `./gradlew :app:bundleRelease :app:assembleRelease -PversionCode=N`。缺签名时发布构建应失败。记录提交、产物、包名、版本、目标 API、ABI 和 SHA-256。[原生构建和发布签名](../app/build.gradle.kts)
- [ ] 使用 `bash store/verify-native-release.sh . "$UPLOAD_CERTIFICATE_SHA256" "$RELEASE_VERSION_CODE"` 构建并验包。核对 AAB 与 APK 的上传证书、清单、AAB 16 KiB 打包配置、APK ZIP 对齐、ELF `PT_LOAD` 对齐和内置模型。记录 `adb shell getconf PAGE_SIZE` 返回 `16384` 的设备启动和场景验证结果。[原生发布验包脚本](verify-native-release.sh) · [Android 16 KB 页支持](https://developer.android.com/guide/practices/page-sizes)
- [ ] 在窄屏、大屏与 API 36 设备上安装候选包，验证探索或搜索打开正文、原生与网页切换、脚注返回、断网读离线副本、正文与三维双向返回、内置及下载后离线渲染、旋转全屏、暂停续传与校验失败、工单测试、浅深主题和系统返回。收集带环境和版本的验收结果，复核 WebView、合并清单权限与明文网络配置。[Android 清单](../app/src/main/AndroidManifest.xml)
- [ ] 按账号适用条件走内部、封闭或生产轨道。若为 2023-11-13 后创建的个人开发者账号，先满足至少 12 位测试人员连续加入封测 14 天并申请生产权限。在 Console 看预发布报告和政策审查状态，再由账号所有者决定提交和发布。[个人账号封测要求](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
