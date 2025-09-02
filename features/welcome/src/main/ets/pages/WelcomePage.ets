import { PreferencesUtil } from "utils"
import { Exam } from "../view/Exam";
import { Guide } from "../view/Guide";
import { Instruction } from "../view/Instruction";
import { Knowledge } from "../view/Knowledge";
import { Result } from "../view/Result";

@ComponentV2
export struct WelcomePage {
  @Consumer('ac')isApproved: boolean = false
  @Provider('sc')swiperController: SwiperController = new SwiperController();
  
  // 考试相关状态管理
  @Provider('examScore') examScore: number = 0
  @Provider('examAnswers') examAnswers: number[] = []
  @Provider('examCompleted') examCompleted: boolean = false
  @Provider('isApproved') isApprovedLocal: boolean = false

  build() {
    Stack() {
      Swiper(this.swiperController) {
        Guide()
        Knowledge()
        Instruction()
        Exam()
        Result()
      }
      .loop(false)
      .backgroundColor($r('app.color.background_primary'))
      .border({ width: $r('app.float.border_width_normal'),
                radius: $r("app.float.border_radius_lg"),
                color: $r("app.color.border_primary" )})
      // .disableSwipe(true).indicatorInteractive(false)
    }
    .alignContent(Alignment.Center)
    .width('100%')
    .height('100%')
  }
}