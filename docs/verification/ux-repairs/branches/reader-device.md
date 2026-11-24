# API 26 窄屏长脚注定位验包

## 产物

| 项 | 内容 |
| --- | --- |
| HAP | [下载独立测试包](</private/tmp/anomicon-uxreader-2877633.6DWao1/uxreader.hap>)（28,350,400 字节，unsigned debug） |
| SHA-256 | `9f0557e7f00972639733c4353859a00fd68f644405e0e25e405d2c9e9c9e9b91` |
| 来源 | Git `2877633b610729f4ea7e052038f5ac7b79be92ba` |
| 包清单 | `com.suixin.anomicon.uxreader`，`phone`，`EntryAbility`，`1.2.7`（1020007）。HarmonyOS SDK `26.0.0.105`，min/target API 均为 `260000026` |

宿主直接打开本地测试文章，将阅读区限宽至 420 vp，保持在生产阅读器的窄屏分支。文章启动时经过 `ScpNativeHtmlParser`、生产文档映射器和索引。状态栏放大镜、搜索输入、自动展开请求、列表滚动和高亮均来自合并提交的生产组件。临时宿主负责保存搜索开关与折叠键。[测试宿主](</private/tmp/anomicon-uxreader-2877633.6DWao1/src/products/phone/src/main/ets/pages/ReaderProbePage.ets>) · [Wikidot 测试文章](</private/tmp/anomicon-uxreader-2877633.6DWao1/src/products/phone/src/main/ets/pages/ReaderProbeArticle.ets>) · [构建日志](</private/tmp/anomicon-uxreader-2877633.6DWao1/build.log>)

## 协调人实机操作

1. 在目标 API 26 模拟器上校验并安装独立包，启动测试文章。

   ```sh
   HAP=/private/tmp/anomicon-uxreader-2877633.6DWao1/uxreader.hap
   shasum -a 256 "$HAP"
   hdc install "$HAP"
   hdc shell aa start -b com.suixin.anomicon.uxreader -a EntryAbility
   ```

2. 在页面顶部阅读状态栏点右侧放大镜「文内查找」，输入框提示为「在文内查找…」，ID 为 `articleSearchInput`。
3. 输入完整的 `lateprobe`，保持搜索栏开启。等待布局稳定，记录搜索栏的 `1 / 1`、`脚注 1`，并截图、记录下表中第 61 段正文的位置及高亮。
4. 全选输入框中的文字并替换成 `foldprobe`。保持附录此前处于收起状态，让搜索操作触发展开。记录相同的结果计数、上下文和折叠子段的可见位置及高亮。若需独立重复本项，可执行 `hdc shell aa force-stop com.suixin.anomicon.uxreader`，再用步骤 1 的启动命令打开文章。

| 搜索词 | 正文中应出现的完整文字 | 命中块的 UI ID |
| --- | --- | --- |
| `lateprobe` | F061 LANDING 第六十一段。这条常规段落的最后一个词是 lateprobe | `article:<实例ID>:block:SCP-999:fn:1:60` |
| `foldprobe` | FOLD INNER 脚注附录。这个段落只在折叠区展开后可见，目标词是 foldprobe | `article:<实例ID>:block:SCP-999:fn:1:61:0` |

`<实例ID>` 由当前渲染器生成。判定落点时，使用以表内块键结尾的正文节点和搜索栏下方实际可见的段落。搜索框本身和命中摘要也含有查询词。记录时可同时保留 `article:<实例ID>:list`、目标块的屏幕坐标，以及正文内匹配词的高亮截图。

## 构建端实测

- `git archive` 导出指定提交，在临时目录执行 `assembleHap` 成功。包内清单、启动页和 Ark 字节码已检查，ZIP 全部条目通过 CRC 校验。
- 原生 HTML 解析器、文档映射器、搜索索引、阅读状态栏和正文渲染器五个源文件的 Git blob 与来源提交逐一匹配。
- 在此次构建的编译输出上执行同一测试文章，确认脚注 1 有 60 个前置段落、第 61 段和一个默认收起的折叠块，脚注 2 有 20 个后续段落。两个搜索词均返回上表的唯一结果。第二个结果要求展开 `SCP-999:fn:1:61`。匹配文字均被标记为高亮段。
- 此次构建上的阅读交互主机回归通过 6/6 项。安装、点击、截图和可见坐标由协调人在目标模拟器上记录。
