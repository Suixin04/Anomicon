# 阅读器修复分支验证

| 项目 | 值 |
| --- | --- |
| 分支 | `fix/ux-reader` |
| 提交 | `a09ef64660a210ea07f4368ed77e656ea183cff1` |
| Git tree | `54c42fd323fd5c56852cc95136a7f0001993fef2` |
| 父提交 | `76ca86302bc2635699b45fe868e866c4867b5b65` |
| 分支起点 | `04996ca327c8f2123ca8967bd9f5628aa1eda1ca` |
| 构建环境 | 本机 DevEco Studio，HarmonyOS SDK 26.0.0，默认 debug 手机目标 |

## 实测结果

| 路径 | 观测结果 |
| --- | --- |
| 折叠区与隐藏标签内的正文 | SDK 生成的组件回调先展开祖先、切换标签并滚到外层行。向布局回调提供同一行内第 1 段与第 61 段的窗口坐标后，分别记录到 `scrollBy(0, 20)` 与 `scrollBy(0, 2420)`，随后高亮对应子块。页面退出时会解除等待中的布局监听。 |
| 脚注与专用组件 | Hypium 验证了同一脚注出现两次时，返回位置指向首次引用的第 61 段，并保留折叠键和第二个标签。组件回归检查了普通子块、列表项、表格行和单元格、标签标题的实际节点标识。 |
| 长脚注内搜索 | 脚注包含 61 个普通段落，最后还有默认收起的子段。主机回归从 Wikidot HTML 走原生解析、文档映射、索引和编译后的搜索回调。旧提交搜索“后段”误到 `fn:1:0`。返修后落到 `fn:1:60` 并二次滚动 2420 vp。搜索“折叠内”会展开 `fn:1:61`，落到 `fn:1:61:0` 并滚动 2460 vp。重复词只计一条结果，跨段短语定位到起始段。 |
| 文末已读 | 用 SDK 编译出的页尾构建器创建系统 Button，分别激活“标为已读”和“取消已读标记”，每次调用一次切换回调。原有 72 vp 上滑松手路径一并编译。 |
| 网页阅读活动 | 在受控时钟下，每 30 秒向网页组件输入触摸移动和滚轮事件，同帧重复输入合并。原有空闲策略在第 180 秒仍计到 180 秒，同一网页从开始静置 180 秒时只计 90 秒。加载进度不会增加交互，页面关闭进度事件后键盘输入也不会上报。 |
| 系统浏览器交接 | 依次递交首页、同篇 `/offset/2`、`/offset/2#notes` 和后退提交事件。实际菜单动作经 URL 策略送到受控 `openLink` 的地址依次匹配。子框架导航不覆盖主文档地址，网页输入地址保持为入口。 |
| 字符实体 | 原生 HTML 经过解析和文档映射后，`&#x20000;`、`&#128512;`、`&amp;lt;`、`&#x4E2D;` 分别得到 `𠀀`、`😀`、字面 `&lt;`、`中`。同一用例还检查了链接属性及字面数字引用。 |
| 构建和依赖 | 手机 HAP 构建成功，产物为默认未签名调试包。原有严格架构检查通过，网页视图依赖 presentation 适配器，平台控制器和对应事件位于适配器中。 |

文章模块 Hypium 共 49 项通过，失败、错误、忽略均为 0。另有 6 项编译后组件主机回归全部通过。测试使用现有 SDK 与依赖，无需占用共享模拟器。布局坐标、平台输入和系统 `openLink` 由主机测试提供。屏幕上的最终像素位置、读屏焦点、真实键鼠输入及系统浏览器启动仍待设备验证。

## 复跑

在阅读工作树根目录运行以下命令。组件主机回归读取本次手机构建生成的代码。

```sh
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export PATH="/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH"
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
"$HVIGOR" --mode module -p product=default -p module=phone@default assembleHap --no-daemon
"$HVIGOR" --mode module -p product=default -p module=article@default test --no-daemon
node --test scripts/test-reader-interactions.mjs
node scripts/architecture-check.mjs --strict
```
