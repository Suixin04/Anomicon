# 设置分支修复回执

| 项目 | 值 |
| --- | --- |
| 分支 | `fix/ux-settings` |
| 提交 SHA | `48a231657b74f3f00a1961fee85bbf36d1a43a43` |
| Git tree | `2759d9b930ce2bc2b6e233c16b43f5ccd9d631e7` |
| 父提交 | `04996ca327c8f2123ca8967bd9f5628aa1eda1ca` |

## 分支自验

| 场景 | 结果和证据 |
| --- | --- |
| 搜索页原路返回 | 本地 Hypium 复用同一个搜索 ViewModel。在它隐藏期间清空共享历史，重新激活的快照显示 0 条历史，同时保留查询 `173`、原系列和 `SCP-173` 结果。 |
| 写盘失败后重试 | 存储替身分别保存磁盘与缓存状态，模拟缓存先变、写盘随后失败。两次清空均向调用方返回错误，`SCP-055` 仍可见。恢复写盘后再次清空，重建服务读到 0 条。主机执行设置页实际的清空方法，两次均显示“清空搜索历史失败，请重试”，成功时才显示“搜索历史已清空”。搜索页垃圾桶也接收相同的失败反馈。 |
| 离线清单延迟返回 | 让一次统计停在离线计数，先读到 1 条历史并完成清空。统计放行后离线篇数为 4，历史数仍为 0，扫描总数为 1。设置页首次显示只发起一次统计。 |
| 四个二级页顶栏 | 检查了关于、内容许可、探索集合、资料库集合的四条调用链。路由均注入共享的 `SettingsViewModel`，目的页在生成顶栏样式时读取 `immersiveMaterialEnabled`。顶栏工厂的布尔参数现为必传，手机 HAP 编译通过。 |

## 可复核的命令和结果

在设置工作树执行以下命令。测试使用 DevEco 本地预览测试器。手机包只做构建，设备视觉效果及真机文件系统故障注入留待集成验收。

```sh
hvigorw --no-daemon --mode module -p module=catalog@default -p product=default test
hvigorw --no-daemon --mode module -p module=settings@default -p product=default test
hvigorw --no-daemon --mode module -p module=phone@default -p product=default test
hvigorw --no-daemon --mode module -p module=phone@default -p product=default assembleHap
```

- **catalog** 共 41 例，38 通过，3 报错。本次新增的旧页回显、删除失败与重试、新增记录写盘重试全部通过。3 个错误均在本分支未修改的 `CachedArticleRepo` 用例中，堆栈止于 `ScpWikiUrlPolicy.normalizePageUrl` 的“`SCP 页面地址无效`”。以 Hypium 报告为准，Hvigor 对此批测试返回 0。
- **settings** 4/4 通过。**phone** 1/1 通过，即延迟离线计数用例。
- **手机 HAP** 构建成功。`git diff --cached --check` 通过，提交后设置分支工作树干净。整个自验在主机完成，未操作共享模拟器。

写入失败后重新打开磁盘状态，避免已变更的 SDK 缓存把相同的删除当作无修改。参见 [Preferences 的刷新约定](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkdata/js-apis-data-preferences.md#flushsync14)及[原生缓存写入实现](https://github.com/openharmony/distributeddatamgr_preferences/blob/master/frameworks/native/src/preferences_impl.cpp)。
