# Anomicon - SCP基金会百科应用

## 项目概述
Anomicon是一个基于ArkTS开发的SCP基金会百科应用，提供SCP项目、故事和资料的浏览功能。

## 主要功能
- SCP项目图鉴浏览：使用本地解析的模拟数据展示SCP项目
- SCP故事阅读：使用本地解析的模拟数据展示SCP故事（待开发完整功能）
- 收藏功能：可以收藏SCP项目或故事（待开发）
- 设置页面：应用设置（待完善）
- 分享功能：分享SCP项目或故事（待开发）

## 技术栈
- 开发框架：ArkUI
- 语言：ArkTS
- 状态管理：AppStorageV2
- 数据来源：本地模拟数据（mockSCPs）

## 项目结构
```
entry/src/main/ets/
├── data/        # 数据层，包含本地模拟数据
├── pages/       # 页面组件
│   ├── Homepage.ets  # 主页面（图鉴）
│   ├── Story.ets     # 故事页面（待开发）
│   ├── Favourite.ets # 收藏页面（待开发）
│   └── Settings.ets  # 设置页面
├── utils/       # 工具类
└── services/    # 服务层（待开发）
```

## 运行指南
1. 确保已安装DevEco Studio
2. 克隆本项目
3. 在DevEco Studio中打开项目
4. 运行预览器或部署到设备

## 未来计划（TODO）
- 支持在线解析SCP数据，替代本地模拟数据
- 完善收藏功能，支持持久化存储
- 实现分享功能，将SCP项目或故事分享到其他应用
- 完善故事页面和收藏页面的交互和功能