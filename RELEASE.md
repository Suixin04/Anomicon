# 发布指南

## 🚀 首次发布流程

### 1. 准备GitHub仓库
1. 在GitHub创建新仓库：`anomicon`
2. 推送本地代码：
```bash
git init
git add .
git commit -m "Initial commit: SCP图鉴应用"
git branch -M main
git remote add origin https://github.com/suixin/anomicon.git
git push -u origin main
```

### 2. 创建Release

#### 自动发布（推荐）
使用GitHub Actions自动化发布：

创建 `.github/workflows/release.yml`：
```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          
      - name: Build
        run: |
          # 这里添加你的构建命令
          echo "Building Anomicon..."
          
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            products/default/build/outputs/**/*.hap
          generate_release_notes: true
```

#### 手动发布
1. 打标签：
```bash
git tag -a v1.0.0 -m "First stable release"
git push origin v1.0.0
```

2. 在GitHub创建Release：
   - 进入仓库 → Releases → "Create a new release"
   - 选择标签：v1.0.0
   - 标题：Anomicon v1.0.0
   - 描述：
```markdown
## 🎉 Anomicon v1.0.0 正式发布！

首个稳定版本，包含完整的SCP图鉴浏览功能。

### ✨ 新功能
- 完整的SCP项目浏览
- 智能搜索功能
- 收藏系统
- 每日推荐
- 分享功能

### 📱 下载
- [App下载](https://github.com/suixin/anomicon/releases/download/v1.0.0/anomicon-v1.0.0.hap)
- [使用指南](https://github.com/suixin/anomicon#readme)

### 🙏 致谢
感谢SCP基金会和所有贡献者！
```

### 3. 应用商店发布

#### 华为应用市场
1. 注册[华为开发者账号](https://developer.huawei.com/consumer/cn/)
2. 创建应用 → 填写信息
3. 上传应用包
4. 等待审核（通常1-3个工作日）

#### 其他平台
- GitHub Releases（直接分发）

## 📋 版本管理规范

### 版本号规则
采用语义化版本：`主版本.次版本.修订版本`
- **主版本**：重大功能更新或不兼容变更
- **次版本**：新功能添加，向下兼容
- **修订版本**：bug修复和微小改进

### 发布检查清单
- [ ] 代码通过测试
- [ ] 更新版本号
- [ ] 更新CHANGELOG.md
- [ ] 构建发布包
- [ ] 创建GitHub Release
- [ ] 更新文档
- [ ] 发布公告

## 🔄 持续集成

### 建议的CI/CD流程
1. **开发阶段**：每次push触发构建测试
2. **发布阶段**：tag推送触发自动发布
3. **文档更新**：自动部署到GitHub Pages

### 分支策略
- `main`：稳定分支，仅接受release
- `develop`：开发分支，日常开发
- `feature/*`：功能分支，新功能开发