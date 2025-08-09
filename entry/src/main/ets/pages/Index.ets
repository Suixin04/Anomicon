import { AppStorageV2 } from "@kit.ArkUI";

@Entry
@ComponentV2
struct Index {
  // pathStack : NavPathStack = new NavPathStack();
  pathStack : NavPathStack = AppStorageV2.connect(NavPathStack, 'navStack', () => new NavPathStack())!

  build() {
    Navigation(this.pathStack){
    }.onAppear(() => {
      this.pathStack.pushPathByName("Homepage", null, false);
    })
    .hideNavBar(true)
  }
}