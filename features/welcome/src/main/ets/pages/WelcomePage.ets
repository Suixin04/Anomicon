import { PreferencesUtil } from "utils"
import { Exam } from "../view/Exam";
import { Guide } from "../view/Guide";
import { Instruction } from "../view/Instruction";
import { Knowledge } from "../view/Knowledge";
import { Result } from "../view/Result";
import { ExamManager } from "../model/ExamManager";

@ComponentV2
export struct WelcomePage {
  @Consumer('ac')isApproved: boolean = false

  @Provider('sc')swiperController: SwiperController = new SwiperController();
  @Provider('currentQuestion') currentQuestion: number = 0
  @Provider('textTimerController') textTimerController: TextTimerController = new TextTimerController()
  @Provider('navScroller') navScroller: Scroller = new Scroller();

  startExam() {
    this.textTimerController.reset()
    this.textTimerController.start()
  }

  submitExam() {
    this.textTimerController.pause()
    this.swiperController?.showNext()
  }

  calculateScore(): number {
    return 0
  }

  build() {
    Stack() {
      Swiper(this.swiperController) {
        Guide()
        Knowledge()
        Instruction()
        Exam()
        Result()
      }
      .onChange((index: number) => {
        if(index === 3) {
          this.startExam()
        }
      })
      .loop(false)
      .backgroundColor($r('app.color.background_primary'))
      .border({ width: $r('app.float.border_width_normal'),
                radius: $r("app.float.border_radius_lg"),
                color: $r("app.color.border_primary" )})
      .disableSwipe(true).indicatorInteractive(false)
    }
    .alignContent(Alignment.Center)
    .width('100%')
    .height('100%')
  }
}