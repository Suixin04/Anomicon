# 三维档案修复回执

| 分支 | 提交 SHA | Git tree |
| --- | --- | --- |
| `fix/ux-models` | `f5c6220c8f767ac8729f83bd3d442cd762a9a091` | `12a189fa02de7873516e3b35dc54e78fe4275321` |

基线为 `04996ca327c8f2123ca8967bd9f5628aa1eda1ca`。编译、交互回归和提交均在三维工作树完成，提交时工作树干净。

## 正文获取模型与卡片续传

主机回归从正式路由表创建正文、查看器和档案馆，执行编译后的菜单与按钮回调，并使用生产下载用例和仓库。ArkUI 控件、系统下载服务、文件存储及原生场景加载在主机测试中用替身驱动。复验时从分支根目录运行下列命令，环境使用 DevEco Studio 的 API 26 SDK，`DEVECO_SDK_HOME` 指向 SDK 根目录。

```sh
hvigorw --no-daemon --mode module -p module=phone@default -p product=default -p buildMode=debug assembleHap
node tools/archive3d/verify_acquisition.mjs
hvigorw --no-daemon --mode module -p module=phone@ohosTest -p product=default -p buildMode=debug assembleHap
```

- **正文首次获取通过。** SCP-131 正文菜单打开三维档案。缺件时点击“获取此模型”，档案馆只呈现 SCP-131。下载完成后，卡片显示“已下载”和“查看模型”。点卡片返回原查看器，栈中仅有正文和该查看器，场景加载端收到该模型的沙箱来源。
- **两种恢复路径通过。** 给同一系统任务替身保留 4,096 字节，并从系统端报告暂停。依次重开档案馆、重建用例和仓库后再开档案馆。两次都显示“已暂停”和“继续下载”。点击后转为“下载中”。任务编号 `42`、令牌、暂存路径和已有字节数保持一致。整个流程共创建 1 次任务、继续 2 次。无指定模型时，档案馆仍展示 10 项资源。
- 正式入口和 `ohosTest` 均生成未签名的 Debug HAP。真实网络下载字节、系统下载通知和真机渲染首帧仍待设备验证。

## 控制栏

协调人报告在 API 26 安装独立预览，使用同一生产控制栏测完浅色/深色 × 材质开/关 × 自动旋转开/关，共 8 组。8 次复位均触发。截图测得浅色自动旋转关闭时文字对比度为 5.72∶1，开启时为 6.73∶1，复位为 10.44∶1。父面板与复位按钮均有可辨边界。现有测试包入口可切换材质、旋转并查看复位计数。[八种组合截图](../archive-controls.png)

| 冻结版本的输入 | SHA-256 |
| --- | --- |
| 生产控制栏 | `a6e43f776a8d4eff3f67e84abfd30501ff23ae564347f366bd320ee6c94b0d35` |
| 浅色颜色资源 | `cacee0d5b3e40e6843c69fe66b8f5a9a80176caa4c2f4c4c580866ade8f251d6` |
| 深色颜色资源 | `7fa7f8e67e1247ac6bd696da9b36f1eaa38f336e2699eb44dfa3f3a4ddc62fe1` |

分支差异通过 `git diff --cached --check`。全仓架构检查返回 1，唯一报错是基线正文网页组件直接引用 ArkWeb。已核对该组件及检查脚本均与基线一致，此问题由阅读组处理。
