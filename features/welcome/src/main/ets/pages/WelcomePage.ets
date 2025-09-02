import { PreferencesUtil } from "utils"

@ComponentV2
export struct WelcomePage {
  @Consumer('ac')isApproved: boolean = false

  build() {
    Stack() {
      Swiper() {
        Text('0')
          .width('90%')
          .height('100%')
          .backgroundColor(Color.Gray)
          .textAlign(TextAlign.Center)
          .fontSize(30)

        Text('1')
          .width('90%')
          .height('100%')
          .backgroundColor(Color.Green)
          .textAlign(TextAlign.Center)
          .fontSize(30)

        Text('2')
          .width('90%')
          .height('100%')
          .backgroundColor(Color.Pink)
          .textAlign(TextAlign.Center)
          .fontSize(30)
      }
      Button()
        .onClick(() => {
          this.isApproved = !this.isApproved
          PreferencesUtil.saveApproveStatus(this.isApproved)
        })
    }
  }
}