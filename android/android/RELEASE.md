# Android 发布验证

在 Flutter 项目目录运行。当前基线为 Flutter 3.47.2、JDK 17、Android SDK 36、NDK 28.2.13676358。

`flutter build apk --debug` 可用于设备调试。发布构建要求由外部机密配置提供四个环境变量。

| 变量 | 内容 |
| --- | --- |
| `ANOMICON_UPLOAD_KEYSTORE` | keystore 的绝对路径 |
| `ANOMICON_UPLOAD_STORE_PASSWORD` | keystore 密码 |
| `ANOMICON_UPLOAD_KEY_ALIAS` | 上传密钥别名 |
| `ANOMICON_UPLOAD_KEY_PASSWORD` | 上传密钥密码 |

从 Play Console 的上传密钥证书取得 SHA-256 指纹。首次发布可使用批准的上传证书指纹。

```bash
set -e
flutter build appbundle --release
bundle=build/app/outputs/bundle/release/app-release.aab
bash android/verify-upload-signature.sh "$bundle" "$UPLOAD_CERTIFICATE_SHA256"
bundletool validate --bundle="$bundle"
bundletool dump manifest --bundle="$bundle" --module=base
bundletool dump config --bundle="$bundle"
```

确认包名为 `com.suixin.anomicon`、目标 API 至少为 36，并检查版本号是否满足发布要求。检查 AAB 配置中的 `PAGE_ALIGNMENT_16K`。用 `zipalign -v -c -P 16 4` 检查生成的 APK，并在 16 KB 页的 Android 设备上打开内置和已下载的三维模型。

RAISA 附件使用 Android 系统文档选择器。验证图片和普通文件选择、取消、2 MiB 单件边界和 Dart 的合计限额。
