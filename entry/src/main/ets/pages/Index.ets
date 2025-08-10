import { AppStorageV2 } from "@kit.ArkUI";

// 应用程序主入口组件
@Entry
@ComponentV2
struct Index {
  // 导航路径栈，用于管理页面导航
  // 通过AppStorageV2连接全局状态管理，确保导航状态在组件间共享
  pathStack : NavPathStack = AppStorageV2.connect(NavPathStack, 'navStack', () => new NavPathStack())!

  build() {
    // 使用Navigation组件构建应用导航框架
    // Navigation组件是应用的基础导航容器
    Navigation(this.pathStack){
      // 组件内容区域，可根据需要添加页面内容
    }
    // 页面生命周期钩子：当组件出现时执行
    .onAppear(() => {
      // 页面加载时，默认跳转到主页
      // pushPathByName方法将指定页面添加到导航栈中
      // 参数说明：
      // 1. 页面名称 "Homepage"
      // 2. 页面参数 null (无额外参数)
      // 3. 是否替换当前页面 false (不替换)
      this.pathStack.pushPathByName("Homepage", null, false);
    })
    // 隐藏默认导航栏
    // 通过hideNavBar方法设置为true来隐藏系统默认导航栏
    .hideNavBar(true)
  }
}