# 格异录 Anomicon · 功能与渲染普查

**最先值得处理的是离线副本的完整性。** 更新失败可以让上一次已经存好的图文也缺图，正常更新又有机会跳过网络检查。两条路径都能给读者一个与实际内容不符的结果。普通正文有正向对照，API 26 模拟器首次打开 SCP-173 时，原生和原版网页都显示了照片、图注和正文。[离线读写实验](<evidence/offline.json#L48>) · [原生首屏](<evidence/reader-173.png>) · [原版网页界面树](<evidence/runtime.json#L38>)

在六组独立复核的用户路径中，共保留 **23 项体验问题，P2 18 项、P3 5 项**。已核实的路径中没有达到 P0 或 P1 的问题。P2 表示在明确条件下影响内容、状态或操作能否完成，P3 表示影响较小或已有可行绕路。置信度衡量的是“在写明的条件下是否发生”，实际用户遇到这些条件的比例尚待统计。

## 范围与复核

基线为本地 `main` 的 `04996ca`，应用版本为 1.2.7（1020007）。与本地 `origin/main`（`bd3b5a0`）相比领先 9 次提交，涉及 116 个文件，增加 17,308 行、删除 1,272 行。普查对象是该基线上的现有功能，最近改动用于安排检查顺序。九个模块共 287 个受版本控制的 ArkTS 文件，其中生产目录有 233 个。六组证据列出了 106 个去重后的重点文件。产品声明支持手机、平板和二合一设备。[产品定义](<../../../build-profile.json5>) · [应用版本](<../../../AppScope/app.json5>) · [设备声明](<../../../products/phone/src/main/module.json5#L7>)

CooperAgent 将任务分为六组，每组的交付版本由另一位成员核查。按改动体量（3）、20 个改动重点路径（80）、数据一致性（4）、并发（4）和界面可访问性（2）计算，审查预评分为 93，用于确定抽样深度。协调者额外构建并安装独立包名的 Release，在同一台 API 26 模拟器用真实入口核对界面。复核记录中的主机实验执行项目逻辑，并按个案替换网络、存储、时间或滚动接口。[运行记录](<evidence/runtime.json>)

| 用户路径 | 本组检查重点 | 列出的文件 | 问题数 | 逐项证据 |
|---|---|---:|---:|---|
| 正文阅读 | 目录、搜索、脚注、两种阅读器、读完与计时 | 13 | 4 | [分组记录](<evidence/reader.json>) |
| 离线与解析 | 解析、临时缓存、永久副本与故障恢复 | 22 | 4 | [分组记录](<evidence/offline.json>) |
| 探索与图鉴 | 主站与中文原创目录、搜索、故事及弱网等待 | 19 | 4 | [分组记录](<evidence/discovery.json>) |
| 资料库与终端 | 考核回执、阅历跨日、续读投影与裁剪 | 22 | 4 | [分组记录](<evidence/library.json>) |
| 导航与设置 | 搜索与设置返回、持久化、窗格和材质偏好 | 33 | 4 | [分组记录](<evidence/shell.json>) |
| 三维档案 | 内置资源、场景首帧、按需获取与暂停恢复 | 20 | 3 | [分组记录](<evidence/models.json>) |

## 实测与讨论如何改变判断

| 实际操作 | 观察和证据界限 |
|---|---|
| 首次从探索搜索 SCP-173，在原生与原版网页之间切换，再保存离线副本 | 两种阅读器均显示图文，保存后菜单显示“离线已就绪 · 更新副本”。这覆盖首次取文、绘制和初次保存。副本跨版本更新另有故障注入用例。[首屏](<evidence/reader-173.png>) · [两种阅读器与保存](<evidence/runtime.json#L17>) |
| SCP-173 原生单篇读到底，先点提示，再触屏上拉 | 点击后仍为“已读 100%”，上拉后为“已读完 · 进度已锁定”。从纯键盘或实际读屏软件完成整条路径仍待验证。[两次操作的界面树](<evidence/runtime.json#L151>) |
| 清除两条已落盘的搜索历史，连续返回旧搜索页，再退出重进 | 设置先确认删除。旧页仍可点击两个历史词，新建页只显示随机发现。可以把本次现象定位到旧页面持有的列表。[清空后旧页](<evidence/history-after-clear.png>) · [三步对照](<evidence/runtime.json#L179>) |
| 从两篇正文进入三维档案并点重试 | 已内置的 SCP-173 在该模拟器创建场景管理器失败，未安装的 SCP-131 反复提示去档案馆获取。两者都能阅读模型资料。四个打包 GLB 均有有效 glTF 场景和网格。[SCP-173](<evidence/3d-173.png>) · [SCP-131](<evidence/3d-131.png>) · [日志和资源摘要](<evidence/runtime.json#L236>) |

图鉴的 3 个主机测试都在解析有效的 SCP-173 地址时报“`SCP 页面地址无效`”。三组目标断言分别检查 200 先返回正文而缓存仍在排队写入、304 返回前旧正文已删除，以及较晚到达的 304 如何处理较新的缓存正文。三次运行均在断言之前退出。离线组、阅读组和协调者各发言一次。协调者结合模拟器首次打开同一条目的结果，把结论限定为主机回归覆盖缺口。网络重验的三种竞争顺序仍须单独验证。[URL 解析地点](<../../../features/catalog/src/main/ets/data/ScpWikiUrlPolicy.ets#L23>) · [三种测试的入口](<../../../features/catalog/src/test/ScpPageFetchLifecycle.test.ets#L219>) · [失败用例](<evidence/runtime.json#L291>)

## 问题、触发条件与修复建议

### P2 · 18 项

**已就绪的离线书架会打开另一版正文**（可靠性，置信度 0.99）  
逻辑实验。先离线保存 v1 和图 A，普通联网阅读后临时缓存更新为引用图 B 的 v2。断网从书架重开，页面取 v2，图片清单仍属 v1。若图 B 未另行缓存，读图文章会缺图。清除临时正文后，同一条目能读到完整 v1。 书架入口显式传递“打开已保存版本”，让正文与图片取自同一份副本。 [ContentGateway.ets 第 57 行](<../../../features/article/src/main/ets/data/ContentGateway.ets#L57>) · [操作与反例](<evidence/offline.json#L34>)

**更新副本报错后，上一版也会缺图**（数据完整性，置信度 0.99）  
故障注入。v1 含图 A，v2 改用图 B。代码先覆盖正文、删除 A，最后才提交新清单。独立复核用 SQLite 拒绝此次提交，重开得到 v2 正文和 v1 清单，图片变为 0/1。恢复写入后完整重试为 1/1。 用版本目录准备新包，数据库切换指向成功后再清理旧包。 [RdbOfflineArticleStore.ets 第 285 行](<../../../features/article/src/main/ets/data/RdbOfflineArticleStore.ets#L285>) · [操作与反例](<evidence/offline.json#L64>)

**长折叠块内搜索命中，屏幕仍停在块首**（界面与交互，置信度 0.99）  
逻辑实验。61 段示例中，第 1 段和第 61 段命中的高亮键不同，列表收到相同的第 2 行、行首、−12 vp 滚动指令。展开动作有效，屏外段落仍需手找。普通顶层段落能定位。 容器布局结束后，再把匹配的子块移入视口。 [ArticleNativeRenderer.ets 第 1364 行](<../../../features/article/src/main/ets/presentation/view/ArticleNativeRenderer.ets#L1364>) · [操作与反例](<evidence/reader.json#L25>)

**“更新副本”成功后仍是旧正文**（逻辑正确性，置信度 0.99）  
逻辑实验。保存 v1、清临时缓存，保持联网且原站已有 v2。重开后点更新，HTML 请求为 0 次，保存时间变新，正文仍是 v1。对照路径发出 1 次重验即可取到 v2。 显式更新先检查原文修订，失败时保留旧包并说明结果。 [ArticleViewModel.ets 第 954 行](<../../../features/article/src/main/ets/presentation/viewmodel/ArticleViewModel.ets#L954>) · [操作与反例](<evidence/offline.json#L49>)

**历史删除未写入存储，设置仍提示清空成功**（可靠性，置信度 0.99）  
故障注入。历史服务先清空内存，连续两次写入失败后设置操作仍成功返回 0 条。此时重建服务读回旧词。原服务成功补写后重建才为空。 明确清空命令应等持久化成功再确认，失败时提供重试。 [ScpSearchHistoryService.ets 第 119 行](<../../../features/catalog/src/main/ets/data/ScpSearchHistoryService.ets#L119>) · [操作与反例](<evidence/shell.json#L61>)

**故事目录刷新只成功一半，完整缓存仍会被覆盖**（逻辑正确性，置信度 0.99）  
主机双源实验。初始有译文和原创两条故事，让原创索引返回没有故事链接的页面，刷新后只剩译文，界面仍显示就绪。即使原创来源恢复，在六小时新鲜期内重开仍读到一条，新增请求为 0。强制刷新后恢复两条。 记录各来源是否成功，只替换成功部分，并保留缺失来源的上次结果与重试入口。 [TaleRepositoryAdapter.ets 第 82 行](<../../../features/catalog/src/main/ets/data/TaleRepositoryAdapter.ets#L82>) · [操作与反例](<evidence/discovery.json#L31>)

**部分目录加载失败时，搜索会误报“无匹配条目”**（界面与交互，置信度 0.99）  
主机实验让一个系列返回 503。14/15 个系列加载完成，搜索只属于失败系列的中文标题，视图选择“无匹配条目”并隐藏重试。在同一份目录上改搜已有标题，就能看见部分失败提示和重试。来源恢复后重试可找到原目标。 零命中时也显示目录的覆盖范围，保留相同的重试操作。 [CatalogSearchView.ets 第 969 行](<../../../features/catalog/src/main/ets/presentation/view/CatalogSearchView.ets#L969>) · [操作与反例](<evidence/discovery.json#L59>)

**清空历史后，原路返回还能点开已删除的搜索词**（界面与交互，置信度 0.99）  
模拟器实测。设置计数从 2 条变为“暂无本地搜索记录”并提示清空成功。返回正文，再返回搜索页并清除输入，SCP-131、SCP-173 仍在“历史搜索”中且可点击。退出搜索后重新进入，旧词消失。宽屏从主栏另开设置会替换详情栈，这条路径不会保留原搜索页。 让保留在导航栈的搜索页在恢复显示时重读历史。 [CatalogSearchViewModel.ets 第 205 行](<../../../features/catalog/src/main/ets/presentation/viewmodel/CatalogSearchViewModel.ets#L205>) · [操作与反例](<evidence/shell.json#L45>) · [界面树](<evidence/runtime.json#L179>) · [截图](<evidence/history-after-clear.png>)

**考核成绩已存，刷新失败后重试会多记一次作答**（逻辑正确性，置信度 0.99）  
故障注入。首次通过后，成绩与 15 XP 已保存。令档案刷新失败，页面仍可提交同一答案。重试后次数从 1 变 2，回执显示本次 0 XP，累计只发放一次奖励。 成绩保存成功即出回执，让刷新故障只重试刷新。 [FoundationAssessmentViewModel.ets 第 264 行](<../../../features/library/src/main/ets/presentation/viewmodel/FoundationAssessmentViewModel.ets#L264>) · [操作与反例](<evidence/library.json#L34>)

**从正文进入未安装的三维模型，没有前往获取的动作**（界面与交互，置信度 0.99）  
模拟器实测。首次从 SCP-131 正文进入三维档案，页面提示“该模型尚未下载，请先前往三维档案馆获取。”点唯一恢复按钮“重新加载”，提示照旧。设置内另有档案馆，已装好的模型可通过本地检查。 在错误页提供“获取此模型”，直达对应卡片。 [Scp3DArchivePage.ets 第 826 行](<../../../products/phone/src/main/ets/pages/Scp3DArchivePage.ets#L826>) · [操作与反例](<evidence/models.json#L47>) · [截图](<evidence/3d-131.png>)

**进程跨过午夜，终端把昨天的时长也算进今天的图**（逻辑正确性，置信度 0.98）  
日期对照。昨天只读了 10 分钟，保留进程，今天首次进入终端时，旧快照把同一段同时绘入昨天和今天。用同一账本按新日期计算后今天为 0。 额度和图表都按本地日期查同一份记录，前台跨日时更新。 [TerminalProfileHelpers.ets 第 74 行](<../../../features/terminal/src/main/ets/presentation/model/TerminalProfileHelpers.ets#L74>) · [操作与反例](<evidence/library.json#L49>)

**当前模拟器打不开内置 SCP-173，错误提示只让用户重试**（可靠性，置信度 0.98）  
模拟器实测。首次和重试均没有模型首帧，资料仍能读。进程日志为 `Creating scene manager failed`。发布包四个 GLB 与清单的长度、摘要吻合，均有场景与网格。这次失败发生于创建场景管理器，真机表现待验。 记录失败阶段并提示当前环境的图形能力，在支持 ArkGraphics3D 的真机验证首帧。 [Scp3DArchivePage.ets 第 357 行](<../../../products/phone/src/main/ets/pages/Scp3DArchivePage.ets#L357>) · [操作与反例](<evidence/models.json#L32>) · [截图](<evidence/3d-173.png>) · [进程日志](<evidence/runtime.json#L236>)

**普通原生单篇没有可激活的“标为已读”控件**（界面与交互，置信度 0.98）  
模拟器实测。SCP-173 页尾显示“已读 100%”，点“继续上滑标记已读完”后不变，同位置触屏上拉后显示“已读完 · 进度已锁定”。界面树的提示节点不可点击，源码只接受达到 72 vp 的触摸拖动。键盘和读屏用户受影响的判断来自该入口，网页模式另有菜单。 保留手势，让文末提示可聚焦、可激活，或复用网页模式的完成菜单。 [ScpArticlePage.ets 第 1139 行](<../../../products/phone/src/main/ets/pages/ScpArticlePage.ets#L1139>) · [操作与反例](<evidence/reader.json#L55>) · [上拉前后](<evidence/runtime.json#L151>)

**原版网页持续滚动，研读时间会少记**（逻辑正确性，置信度 0.98）  
计时实验。原生正文已就绪，切原版网页后只在网页里滚动。页面没有把这些操作传给研读会话。用实际计时策略推进 180 秒，仅记 90 秒。原生列表会持续报告滚动。 将网页滚动或触控接入同一研读会话。 [ScpArticlePage.ets 第 1449 行](<../../../products/phone/src/main/ets/pages/ScpArticlePage.ets#L1449>) · [操作与反例](<evidence/reader.json#L40>)

**系统下载已暂停，档案馆仍显示下载中**（可靠性，置信度 0.98）  
状态实验。系统保留部分文件并上报 PAUSED，重开档案馆时适配器将它改为 DOWNLOADING。卡片继续转圈且不能继续下载。失败状态有重试按钮，系统若自行恢复也能接着传输。设备上进入 PAUSED 的频率待测。 保留暂停状态，卡片调用仓库已有的继续下载操作。 [RouteAdapters.ets 第 162 行](<../../../products/phone/src/main/ets/pages/routes/RouteAdapters.ets#L162>) · [操作与反例](<evidence/models.json#L62>)

**清空一条搜索记录也要等整库离线配图逐一检查**（性能，置信度 0.97）  
等待关系实验。设置页获取清空按钮的计数及确认后的结果，都等待离线文章逐篇、配图逐张核验。2 篇正文和 10 张已存图片的对照里，确认清空又执行 12 次文件检查。挂起一次检查时，历史已经清空，界面仍显示“清理中…”。真机等待时长待测。 让历史计数和清空独立完成，离线容量和完整性按需计算。 [SettingsStorageAdapter.ets 第 49 行](<../../../products/phone/src/main/ets/composition/SettingsStorageAdapter.ets#L49>) · [操作与反例](<evidence/shell.json#L76>)

**弱网下全站搜索可能长期只查到已缓存的系列**（可靠性，置信度 0.96）  
主机队列实验。仅有一个系列缓存，持续 WEAK、缺少新鲜原始页时，3 个后台请求入队，启动数为 0。进度停在 1/15，40 秒等待计时已解除。恢复正常配额后达到 15/15 并搜到目标。完全冷启动时首批以用户优先级运行，精确编号也可直达。 让用户针对当前搜索补载缺失范围，在队列受限时说明已覆盖的系列。 [CatalogSearchViewModel.ets 第 560 行](<../../../features/catalog/src/main/ets/presentation/viewmodel/CatalogSearchViewModel.ets#L560>) · [操作与反例](<evidence/discovery.json#L45>)

**热门原创榜只有一行待补标题，已有排名也要等**（性能，置信度 0.96）  
主机榜单实验。本地有两行排名，仅一行需要联网补标题。零后台配额下，两行都没有发布，源码将此时的空列表画成骨架屏。今日推荐已发布一张卡。放行标题请求后，两行排名同时出现。 先发布已有榜单，让缺标题的行独立补全。 [ExploreContentUseCase.ets 第 40 行](<../../../features/explore/src/main/ets/application/ExploreContentUseCase.ets#L40>) · [操作与反例](<evidence/discovery.json#L73>)

### P3 · 5 项

**部分扩展汉字、表情和实体在原生正文中变样**（逻辑正确性，置信度 1.00）  
解析实验。数字引用 U+20000、U+1F600 被截断成 U+0000、U+F600。字面量 `&amp;lt;` 又被多解一层。普通汉字“中”对照正确。出现频率取决于原文编码。 按完整 Unicode 码点做一次实体解码。 [ScpNativeHtmlParser.ets 第 408 行](<../../../features/article/src/main/ets/data/ScpNativeHtmlParser.ets#L408>) · [操作与反例](<evidence/offline.json#L79>)

**关闭“沉浸光感”后，四个二级页仍请求沉浸材质**（界面与交互，置信度 0.99）  
源码与能力分支实验。关于、内容来源与许可、探索集合、资料库集合的顶栏使用默认开启值。能力包含 IMMERSIVE 时这四页仍请求 IMMERSIVE，显式传入关闭值的页面请求 ADAPTIVE。仅支持 ADAPTIVE 时，两者相同。真机观感待测。 在四个目的页传入共享材质开关，并在支持该能力的真机对照。 [AboutPage.ets 第 144 行](<../../../features/settings/src/main/ets/presentation/view/AboutPage.ets#L144>) · [操作与反例](<evidence/shell.json#L92>)

**系列主线已读 19/19，依旧推荐已读终章**（界面与交互，置信度 0.99）  
逻辑实验。读完逆模因部主线，卡片“下一篇”仍打开《尾声：胜冠徒然》。将之前一章改回未读后，卡片能正确回到该章。 满进度时显示“主线已全部读完”，提供明确的目录或重读动作。 [TerminalLibraryAdapters.ets 第 195 行](<../../../products/phone/src/main/ets/composition/TerminalLibraryAdapters.ets#L195>) · [操作与反例](<evidence/library.json#L64>)

**两篇未读完的旧文超过最近 500 条后，只能从资料库找到一篇**（界面与交互，置信度 0.98）  
SQLite 实验。两篇未收藏旧文之后又打开 500 篇。两项进度均仍在，最近列表移出两篇，续读卡只取较新一篇。能自行找到原文的读者仍可恢复位置。 给续读卡增加通往已有完整续读列表的入口。 [TerminalHome.ets 第 300 行](<../../../features/terminal/src/main/ets/presentation/view/TerminalHome.ets#L300>) · [操作与反例](<evidence/library.json#L79>)

**在原版网页翻到下一迭代，再用系统浏览器会回到入口页**（逻辑正确性，置信度 0.98）  
逻辑实验。Web 内部跟随同篇的 `/offset/2` 后，子页面记住新地址，父页面仍把进入网页时的地址交给系统。直接从原生页进入目标迭代时地址正确。 主文档导航完成时同步当前地址给外部打开操作。 [ScpArticlePage.ets 第 1205 行](<../../../products/phone/src/main/ets/pages/ScpArticlePage.ets#L1205>) · [操作与反例](<evidence/reader.json#L69>)

## 建议先做的回归与修复

| 优先顺序 | 负责模块 | 能验证修复的最短用例 |
|---:|---|---|
| 1 | 正文、离线仓库 · P2 | 保存含图 A 的 v1，让原文更新为含图 B 的 v2。分别从书架断网打开、联网点更新、让元数据提交失败再重开。每次都核对正文版本、可打开的图片数和清单总数，失败后应仍可读完整 v1。 [正文选版](<../../../features/article/src/main/ets/data/ContentGateway.ets#L57>) · [包提交顺序](<../../../features/article/src/main/ets/data/RdbOfflineArticleStore.ets#L285>) |
| 2 | 图鉴、搜索与设置 · P2 | 先保留部分目录再查未命中标题，核对界面是否告知搜索范围并可恢复。再从结果进正文及阅读设置，清空历史后原路返回，验证旧词消失。 [搜索分支](<../../../features/catalog/src/main/ets/presentation/view/CatalogSearchView.ets#L963>) · [恢复旧搜索页](<../../../features/catalog/src/main/ets/presentation/viewmodel/CatalogSearchViewModel.ets#L205>) |
| 3 | 原生及网页阅读器 · P2 | 在长折叠块尾部找词后用键盘激活完成，再对照三分钟网页持续滚动和静置。分别断言目标段落可见、可标记已读、研读时长正确。 [原生定位](<../../../features/article/src/main/ets/presentation/view/ArticleNativeRenderer.ets#L1364>) · [网页接入](<../../../products/phone/src/main/ets/pages/ScpArticlePage.ets#L1449>) |
| 4 | 三维档案 · P2 | 用同一 Release 在支持 ArkGraphics3D 的真机打开内置 SCP-173。对 SCP-131 从正文一路获取并返回，再用确实暂停的下载任务验证“继续”。 [场景错误](<../../../products/phone/src/main/ets/pages/Scp3DArchivePage.ets#L357>) · [下载状态](<../../../products/phone/src/main/ets/pages/routes/RouteAdapters.ets#L162>) |
| 5 | 基金会、终端 · P2 | 保存成绩后让画像刷新报错，重试只刷新一次回执。保留进程跨午夜、新一天未阅读时查看今日额度和七日图。 [成绩提交](<../../../features/library/src/main/ets/presentation/viewmodel/FoundationAssessmentViewModel.ets#L264>) · [跨日统计](<../../../features/terminal/src/main/ets/presentation/model/TerminalProfileHelpers.ets#L74>) |

## 领域分布

- 界面与交互 8 项。集中在搜索提示、阅读定位和恢复按钮。
- 逻辑正确性 7 项。计时、进度及版本选择会给出错误结果。
- 可靠性 5 项。持久化、网络或图形服务改变状态时，页面难以恢复。
- 性能 2 项。无关的存储检查会延后用户操作。
- 数据完整性 1 项。离线资源和数据库清单需要一起提交。

## 工程检查与证据边界

- Release 构建成功。为与模拟器原有数据隔离，从基线归档另建副本，仅改包名，安装并执行上述操作。该 HAP 为 25,385,313 字节。验证结束后卸载了审查包。[构建标识与摘要](<evidence/runtime.json#L2>)
- 七个模块共运行 139 个 Hypium 用例，136 成功、3 报错。公共 6/6、正文 47/47、图鉴 35/38、探索 19/19、资料库 15/15、设置 4/4、终端 10/10。Hvigor 测试命令返回 0，统计取自逐例结果。三维与产品壳另计于构建和设备操作，未计入 139 条。[测试计数](<evidence/runtime.json#L267>)
- 架构严格检查返回 1，有 1 个错误、0 个警告。网页阅读视图直接导入 ArkWeb，触发项目的展示层依赖规则。同一版本实际能绘制网页，本条作为工程检查结果列示。[视图导入](<../../../features/article/src/main/ets/presentation/view/ArticleWebRenderer.ets#L1>) · [检查规则](<../../../scripts/architecture-check.mjs#L444>)
- 真机手机、平板、折叠屏、二合一键鼠与系统读屏的实际操作仍需补测。静态检查追踪了 840 vp 分栏和页面重显。折叠动画帧时间、首帧耗时、线上弱网发生率和真实后台模型下载均无此次测量值。[导航与设置覆盖](<evidence/shell.json>) · [三维验证范围](<evidence/models.json>)
- 运行实验中的时钟、SQLite 或存储异常用于验证给定条件下的结果。线上故障发生率、原站字符引用使用率，以及特定阅读设备的视觉影响仍待测量。六组均完成复核，最终提交中因结构不合格剔除 0 项，置信度低于 0.50 压下 0 项，复核缺席或超时 0 组。
