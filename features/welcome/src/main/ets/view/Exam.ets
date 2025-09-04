import { FontSizeManager } from "utils"
import { ExamManager, Question } from "../model/ExamManager";

@ComponentV2
export struct Exam {
  @Consumer('sc') swiperController?: SwiperController
  @Consumer('textTimerController') textTimerController?: TextTimerController
  @Consumer('navScroller') navScroller: Scroller = new Scroller()
  @Local examManager: ExamManager = ExamManager.getInstance()



  selectAnswer(questionIndex: number, answerIndex: number) {
    this.examManager.selectAnswer(questionIndex, answerIndex)
  }

  submitExam() {
    this.textTimerController?.pause()
    this.examManager.submitExam()
    this.swiperController?.showNext()
  }

  nextQuestion() {
    if (this.examManager.getCurrentQuestion() < this.examManager.getQuestionCount() - 1) {
      this.examManager.setCurrentQuestion(this.examManager.getCurrentQuestion() + 1)
      this.navScroller.scrollToIndex(this.examManager.getCurrentQuestion(), true, ScrollAlign.CENTER)
    }
  }

  prevQuestion() {
    if (this.examManager.getCurrentQuestion() > 0) {
      this.examManager.setCurrentQuestion(this.examManager.getCurrentQuestion() - 1)
      this.navScroller.scrollToIndex(this.examManager.getCurrentQuestion(), true, ScrollAlign.CENTER)
    }
  }

  goToQuestion(index: number) {
    this.examManager.setCurrentQuestion(index)
    this.navScroller.scrollToIndex(index, true, ScrollAlign.CENTER)
  }



  build() {
    Column({ space: 20 }) {
      Row() {
        Column({ space: 5 }) {
          Text(`题目 ${this.examManager.getCurrentQuestion() + 1}/${this.examManager.getQuestionCount()}`)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3698d9')
          TextTimer({
            isCountDown: true,
            count: 300000, // 5分钟 = 300秒 * 1000毫秒
            controller: this.textTimerController
          })
            .format('mm:ss')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
            .onTimer((utc: number, elapsedTime: number) => {
              if (elapsedTime <= 0) {
                this.submitExam()
              }
            })
        }.alignItems(HorizontalAlign.Start)

        Blank()

        Text(`${this.examManager.getAnsweredCount()}/${this.examManager.getQuestionCount()} 已答`)
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
        .width('100%')
        .padding({ bottom: 10 })

      // 进度条
      Progress({
        value: this.examManager.getCurrentQuestion() + 1,
        total: this.examManager.getQuestionCount(),
        type: ProgressType.Linear
      })
        .width('100%')
        .color('#3698d9')
        .backgroundColor('#20ffffff')

      // 当前题目
      Column({ space: 15 }) {
        Text(this.examManager.getCurrentQuestionData()?.question || '')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Start)
          .width('100%')

        Column({ space: 10 }) {
          ForEach(this.examManager.getCurrentQuestionData()?.options || [], (option: string, index: number) => {
            Row({ space: 12 }) {
              Radio({ value: `option_${index}`, group: `question_${this.examManager.getCurrentQuestion()}` })
                .checked(this.examManager.getExamAnswers()[this.examManager.getCurrentQuestion()] === index)
                .radioStyle({
                  checkedBackgroundColor: '#3698d9',
                  uncheckedBorderColor: '#3698d9'
                })

              Text(option)
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .textAlign(TextAlign.Start)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.examManager.getExamAnswers()[this.examManager.getCurrentQuestion()] === index ? '#103698d9' : '#101e1e1e')
            .border({
              width: 1,
              color: this.examManager.getExamAnswers()[this.examManager.getCurrentQuestion()] === index ? '#3698d9' : '#20ffffff',
              radius: 8
            })
            .onClick(() => this.selectAnswer(this.examManager.getCurrentQuestion(), index))
          })
        }
      }
        .layoutWeight(1)
        .width('100%')

      // 题目导航
      Row({ space: 8 }) {
        List({ scroller: this.navScroller }) {
          ForEach(this.examManager.getQuestions(), (question: Question, index: number) => {
            ListItem() {
              Text((index + 1).toString())
                .fontSize(12)
                .fontColor(this.examManager.getCurrentQuestion() === index ? $r('app.color.background_primary') :
                         this.examManager.getExamAnswers()[index] !== -1 ? '#3698d9' : $r('app.color.text_tertiary'))
                .width(32)
                .height(32)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.examManager.getCurrentQuestion() === index ? '#3698d9' :
                               this.examManager.getExamAnswers()[index] !== -1 ? '#103698d9' : '#101e1e1e')
                .border({
                  width: 1,
                  color: this.examManager.getCurrentQuestion() === index ? '#3698d9' :
                         this.examManager.getExamAnswers()[index] !== -1 ? '#3698d9' : '#20ffffff',
                  radius: 16
                })
                .onClick(() => this.goToQuestion(index))
            }
            .width(40)
            .height(40)
          })
        }
        .width('100%')
        .height(40)
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
      }
        .width('100%')
        .justifyContent(FlexAlign.Center)

      // 底部按钮
      Row({ space: 10 }) {
        if (this.examManager.getCurrentQuestion() > 0) {
          Button('上一题', { type: ButtonType.Normal })
            .fontSize(FontSizeManager.getScaledFontSize(15))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.background_primary'))
            .backgroundColor('#16B0F2')
            .border({ radius: 8, width: 0, color: $r('app.color.border_primary') })
            .borderRadius(8)
            .onClick(() => this.prevQuestion())
            .layoutWeight(1)
            .padding({ top: 10, bottom: 10 })
        }

        if (this.examManager.getCurrentQuestion() < this.examManager.getQuestionCount() - 1) {
          Button('下一题', { type: ButtonType.Normal })
            .fontSize(FontSizeManager.getScaledFontSize(15))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.background_primary'))
            .backgroundColor('#16B0F2')
            .border({ radius: 8, width: 0, color: $r('app.color.border_primary') })
            .borderRadius(8)
            .onClick(() => this.nextQuestion())
            .layoutWeight(1)
            .padding({ top: 10, bottom: 10 })
        } else {
          Button('提交考试', { type: ButtonType.Normal })
            .fontSize(FontSizeManager.getScaledFontSize(15))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.background_primary'))
            .backgroundColor('#16B0F2')
            .border({ radius: 8, width: 0, color: $r('app.color.border_primary') })
            .borderRadius(8)
            .onClick(() => this.submitExam())
            .layoutWeight(1)
            .padding({ top: 10, bottom: 10 })
        }
      }
        .width('100%')

      Divider()
        .margin({left: -20, right: -20, bottom: 10})
    }
      .padding({ top: 20, bottom: 20, left: 20, right: 20 })
      .width('80%')
      .height('95%')
  }
}