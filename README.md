# Anomicon - SCP基金会百科应用

## 项目概述
Anomicon是一个基于ArkTS开发的SCP基金会百科应用，旨在为SCP爱好者提供一个便捷的、沉浸式的移动端阅读平台。用户可以通过该应用浏览和搜索SCP项目，查看详细的描述、收容措施和相关图片，以及阅读SCP故事。

## 小编推荐
**你的便携式SCP档案馆**

## 主要功能 ✅
- **SCP项目图鉴浏览**：完整的SCP项目列表，支持分页加载和系列筛选
- **SCP故事阅读**：精选SCP故事集，支持故事详情查看
- **智能搜索**：支持按SCP编号、名称、描述等多维度搜索
- **每日推荐**：基于日期算法生成每日推荐SCP项目
- **随机探索**：一键随机发现新的SCP项目
- **收藏功能**：支持收藏SCP项目和故事（本地存储）
- **设置页面**：字体大小调节、应用设置等个性化配置
- **分享功能**：支持分享SCP项目和故事到其他应用

## 技术栈
- **开发框架**：ArkUI (HarmonyOS NEXT)
- **编程语言**：ArkTS
- **状态管理**：AppStorageV2 + 组件级状态管理
- **数据存储**：关系型数据库 (RDB) + 用户首选项 (Preferences)
- **网络请求**：基于现代API的数据获取
- **UI框架**：自定义组件库 + 响应式设计

## 项目结构 📁

### 整体架构
```
Anomicon/
├── products/default/           # 主应用模块
│   └── src/main/ets/
│       ├── entryability/      # 应用入口能力
│       ├── pages/            # 主页面组件
│       └── mock/             # 模拟数据
├── features/                  # 功能模块
│   ├── object/              # SCP项目模块
│   │   └── src/main/ets/pages/
│   │       ├── ObjectPage.ets      # SCP列表页面
│   │       └── ObjDetailPage.ets   # SCP详情页面
│   ├── tale/                # SCP故事模块
│   │   └── src/main/ets/
│   │       ├── data/Data.ets       # 故事数据
│   │       └── pages/
│   │           ├── TalePage.ets    # 故事列表页面
│   │           └── TaleDetailPage.ets # 故事详情页面
│   ├── favourite/           # 收藏模块
│   │   └── src/main/ets/pages/Favourite.ets
│   └── setting/             # 设置模块
│       └── src/main/ets/pages/Setting.ets
├── commons/                 # 公共模块
│   ├── utils/              # 工具类和数据模型
│   │   └── src/main/ets/
│   │       ├── model/       # 数据模型定义
│   │       ├── service/     # 业务服务
│   │       ├── database/    # 数据存储
│   │       └── util/        # 工具函数
│   └── uicomponents/        # UI组件库
└── AppScope/               # 应用级配置
```

### 核心模块说明

#### 1. 数据模型 (`commons/utils/src/main/ets/model/`)
- **SCP接口**：完整的SCP项目数据结构
- **Tale接口**：SCP故事数据结构
- **TabClass**：底部导航栏配置
- **SCPSource**：LazyForEach数据源管理

#### 2. 业务服务 (`commons/utils/src/main/ets/service/`)
- **FavoriteService**：收藏管理
- **ShareService**：内容分享
- **ScpApi**：API数据获取

#### 3. 数据存储 (`commons/utils/src/main/ets/database/`)
- **RDBStoreUtil**：关系型数据库操作
- **PreferencesUtil**：用户首选项存储

#### 4. UI组件 (`commons/uicomponents/`)
- **ScpCardView**：SCP项目卡片
- **SearchBarView**：搜索栏
- **SkeletonScreen**：加载骨架屏
- **ErrorStateView**：错误状态显示

## 功能亮点 ✨

### 1. 智能搜索系统
- 支持模糊搜索和多关键词匹配
- 实时搜索建议
- 搜索结果高亮显示
- 搜索历史记录

### 2. 个性化推荐
- 基于日期的每日推荐算法
- 随机探索功能
- 用户行为分析（未来版本）

### 3. 响应式设计
- 适配不同屏幕尺寸
- 暗黑模式支持
- 字体大小调节
- 无障碍访问支持

### 4. 数据同步
- 在线/离线模式切换
- 数据缓存机制
- 增量更新

## 开发环境要求 🛠️

### 必需工具
- **DevEco Studio**：最新版本（推荐5.0以上）
- **HarmonyOS SDK**：API 12以上
- **Node.js**：18.x以上版本

### 环境配置
1. 安装DevEco Studio
2. 配置HarmonyOS SDK
3. 克隆本项目到本地
4. 在DevEco Studio中打开项目
5. 同步依赖并运行

## 快速开始 🚀

### 1. 克隆项目
```bash
git clone [项目地址]
cd Anomicon
```

### 2. 安装依赖
在DevEco Studio中打开项目后，系统会自动同步依赖。

### 3. 运行项目
- **预览器**：使用DevEco Studio内置预览器
- **真机调试**：连接HarmonyOS设备
- **模拟器**：使用HarmonyOS模拟器

### 4. 构建发布
```bash
# 使用DevEco Studio的构建功能
# 或使用命令行：hvigorw assembleRelease
```

## API接口 📡

### 基础配置
- **基础URL**：可配置的API服务器地址
- **超时设置**：30秒连接超时
- **重试机制**：失败自动重试3次

### 核心接口
- `GET /api/scps`：获取SCP项目列表（分页）
- `GET /api/scps/:id`：获取特定SCP详情
- `GET /api/scps/search`：搜索SCP项目
- `GET /api/tales`：获取故事列表
- `GET /api/tales/:id`：获取故事详情

## 数据流程 🔄

### 1. 数据获取流程
```
用户操作 → API请求 → 数据处理 → 状态更新 → UI渲染
```

### 2. 收藏流程
```
点击收藏 → 本地存储 → 状态同步 → UI反馈
```

### 3. 搜索流程
```
输入关键词 → 防抖处理 → API搜索 → 结果展示
```

## 性能优化 ⚡

### 1. 渲染优化
- **LazyForEach**：大数据列表虚拟滚动
- **组件复用**：减少重复渲染
- **图片缓存**：智能图片加载和缓存

### 2. 内存优化
- **对象池**：复用频繁创建的对象
- **垃圾回收**：及时清理无用引用
- **内存监控**：运行时内存使用监控

### 3. 网络优化
- **请求合并**：减少不必要的网络请求
- **数据压缩**：启用Gzip压缩
- **缓存策略**：智能缓存过期策略

## 测试策略 🧪

### 1. 单元测试
- **业务逻辑**：核心业务函数测试
- **数据模型**：数据验证和转换测试
- **工具函数**：纯函数测试

### 2. 集成测试
- **API测试**：接口正确性和稳定性
- **UI测试**：关键用户流程测试
- **性能测试**：大数据量下的性能表现

### 3. 用户测试
- **可用性测试**：用户体验评估
- **兼容性测试**：不同设备和系统版本
- **稳定性测试**：长时间运行测试

## 贡献指南 🤝

### 开发规范
- **代码风格**：遵循ArkTS官方编码规范
- **提交规范**：使用语义化提交消息
- **分支管理**：Git Flow工作流

### 贡献流程
1. Fork项目仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建Pull Request

## 未来路线图 🗺️

### 近期计划（1-2个月）
- [ ] 完善收藏功能的云同步
- [ ] 添加用户登录和个性化推荐
- [ ] 实现故事阅读进度保存
- [ ] 增加SCP项目分类标签系统

### 中期目标（3-6个月）
- [ ] 支持多语言切换（中英文）
- [ ] 添加社区功能（评论、点赞）
- [ ] 实现离线阅读包下载
- [ ] 增加SCP项目音频朗读功能

### 长期愿景（6-12个月）
- [ ] 支持用户投稿和审核系统
- [ ] 添加AR/VR沉浸式体验
- [ ] 实现跨平台数据同步
- [ ] 构建完整的SCP生态系统

## 技术支持 💬

### 问题反馈
- **GitHub Issues**：项目问题追踪
- **邮件支持**：anomicon@example.com
- **社区论坛**：SCP中文社区

### 开发文档
- [ArkTS开发指南](https://developer.harmonyos.com/arkts)
- [HarmonyOS设计规范](https://developer.harmonyos.com/design)
- [API文档](docs/api.md)

## 许可证 📄
本项目采用MIT许可证，详见[LICENSE](LICENSE)文件。

## 致谢 🙏
- **SCP基金会**：提供丰富的SCP内容
- **开源社区**：各种开源库和工具
- **贡献者**：所有为项目做出贡献的开发者

---

**最后更新：2025年1月**  
**版本：v1.0.0**  
**维护团队：Anomicon开发组**