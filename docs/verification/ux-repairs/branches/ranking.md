# 热门原创榜修复回执

分支 `fix/ux-search`，核验基线 `04996ca327c8f2123ca8967bd9f5628aa1eda1ca`。搜索负责人统一提交下列三个文件。

| 搜索工作树内的文件 | 实测版本 SHA-256 |
| --- | --- |
| [features/explore/src/main/ets/application/ExploreContentUseCase.ets](../../../../features/explore/src/main/ets/application/ExploreContentUseCase.ets) | `f4b085732a0f9be4cd420fbc0f90130f7eeb9e1c61d130f0b6fb06ee65587db3` |
| [features/explore/src/main/ets/presentation/viewmodel/ExploreHomeViewModel.ets](../../../../features/explore/src/main/ets/presentation/viewmodel/ExploreHomeViewModel.ets) | `6f99f0a4fbec9c46595b107bb8292c18d91c76daa83b9f5daf88f45367036b64` |
| [features/explore/src/test/ExploreHomeViewModel.test.ets](../../../../features/explore/src/test/ExploreHomeViewModel.test.ets) | `0fc86c24d1bcdab41ef43e87b345d4654f577b208237db76dfe32ec21012cd29` |

在搜索工作树运行 `node /Users/suixin/codefield/Anomicon/scripts/test-host.mjs explore`，Hypium **20/20 通过**，失败、错误和跳过均为 0。`git diff --check -- features/explore` 通过。

新增回归使用有两行排名的新鲜缓存。第二行 `SCP-CN-963-J` 的标题查询仍在等待时，首页显示两行及原始编号，榜单状态为就绪，榜单网络请求计数为 0。主动刷新一次后，第二行评分从 4508 升至 4509。旧请求返回标题时，页面仍显示该行编号与新评分；当前请求返回后，该行显示“神烦代码”。

另在主机调用现有榜单行的 `openEntry` 和手机首页的 `openContent`，在导航边界记录目标。已有标题行打开 `article` 并传入 `main:scp-cn-001`。待补标题行在补齐前后均打开 `article` 并传入 `main:scp-cn-963-j`。共享设备上的实际点击由集成负责人验证。
