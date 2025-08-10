import { AppStorageV2 } from "@kit.ArkUI";

// 应用程序主入口组件
@Entry
@ComponentV2
struct Index {
  // 导航路径栈，用于管理页面导航
  pathStack : NavPathStack = AppStorageV2.connect(NavPathStack, 'navStack', () => new NavPathStack())!

  build() {
    // 使用Navigation组件构建应用导航框架
    Navigation(this.pathStack){
    }.onAppear(() => {
      // 页面加载时，默认跳转到主页
      this.pathStack.pushPathByName("Homepage", null, false);
    })
    // 隐藏默认导航栏
    .hideNavBar(true)
  }
}