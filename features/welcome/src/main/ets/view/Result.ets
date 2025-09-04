import { FontSizeManager, PreferencesUtil } from "utils"
import { ExamManager, Question } from "../model/ExamManager";

@ComponentV2
export struct Result {
  @Consumer('sc') swiperController?: SwiperController
  @Consumer('textTimerController') textTimerController?: TextTimerController
  @Consumer('navScroller') navScroller: Scroller = new Scroller()
  @Consumer('ac')isApproved: boolean = false
  examManager: ExamManager = ExamManager.getInstance()

  @Local showDetails: boolean = false

  get isPassed(): boolean {
    return this.examManager.getExamScore() >= 80
  }

  get correctCount(): number {
    return this.examManager.getCorrectCount()
  }

  get answeredCount(): number {
    return this.examManager.getAnsweredCount()
  }



  async restartExam() {
    // 重置考试状态
    this.examManager.resetExam()
    this.isApproved = false
    this.navScroller.scrollToIndex(0, true, ScrollAlign.CENTER)
    this.textTimerController?.reset()
    // 跳转到第一个页面（Guide）
    // 这里必须最后执行，所有指令完毕后回到首页
    await this.swiperController?.changeIndex(0, true)
  }

  enterApp() {
    // 设置通过状态
    this.isApproved = true
    // 保存到持久化存储
    PreferencesUtil.saveApproveStatus((true))
  }

  aboutToAppear() {
    // 根据考试结果设置isApproved状态
    if (this.examManager.isExamCompleted()) {
      this.isApproved = this.isPassed
    }
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        // 结果图标和标题
        Stack() {
          Image(this.isPassed ? $r('app.media.circle_check') : $r('app.media.ban'))
            .width(34)
            .height(34)
            // .fillColor(this.isPassed ? '#22c55e' : '#ef4444')
        }
        .width(60)
        .height(60)
        .backgroundColor(this.isPassed ? '#1022c55e' : '#10ef4444')
        .borderRadius(30)
        .padding(13)

        Column({ space: 10 }) {
          Text('考试结果')
            .fontSize(20)
            .fontColor(this.isPassed ? '#22c55e' : '#ef4444')
          Text(this.isPassed ? '恭喜您通过准入考试！' : '很遗憾，您未能通过考试')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }

        // 分数展示
        Column({ space: 15 }) {
          Row() {
            Text('总分')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text(`${this.examManager.getExamScore()}/100`)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isPassed ? '#22c55e' : '#ef4444')
          }
          .width('100%')

          Row() {
            Text('答题情况')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text(`${this.answeredCount}/${this.examManager.getQuestionCount()} 题`)
              .fontSize(14)
              .fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')

          Row() {
            Text('正确题数')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text(`${this.correctCount}/${this.examManager.getQuestionCount()} 题`)
              .fontSize(14)
              .fontColor(this.isPassed ? '#22c55e' : '#ef4444')
          }
          .width('100%')

          // 通过状态
          Row() {
            Text('考试状态')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text(this.isPassed ? '通过' : '未通过')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isPassed ? '#22c55e' : '#ef4444')
          }
          .width('100%')
        }
        .padding(20)
        .width('100%')
        .backgroundColor('#101e1e1e')
        .border({ width: 1, color: this.isPassed ? '#22c55e' : '#ef4444', radius: 8 })

        // 详细答题情况按钮
        Button(this.showDetails ? '隐藏详情' : '查看详情', { type: ButtonType.Normal })
          .fontSize(14)
          .fontColor('#3698d9')
          .backgroundColor('transparent')
          .border({ width: 1, color: '#3698d9', radius: 6 })
          .onClick(() => this.showDetails = !this.showDetails)
          .width('100%')

        // 详细答题情况
        if (this.showDetails) {
          Column({ space: 15 }) {
            Text('详细答题情况')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .textAlign(TextAlign.Start)

            ForEach(this.examManager.getQuestions(), (question: Question, index: number) => {
              Column({ space: 10 }) {
                Row() {
                  Text(`第${index + 1}题`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Blank()
                  Text(this.examManager.getExamAnswers()[index] === question.correctAnswer ? '正确' : '错误')
                    .fontSize(12)
                    .fontColor(this.examManager.getExamAnswers()[index] === question.correctAnswer ? '#22c55e' : '#ef4444')
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .backgroundColor(this.examManager.getExamAnswers()[index] === question.correctAnswer ? '#1022c55e' : '#10ef4444')
                    .borderRadius(4)
                }
                .width('100%')

                Text(question.question)
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')
                  .textAlign(TextAlign.Start)

                if (this.examManager.getExamAnswers()[index] !== question.correctAnswer) {
                  Column({ space: 5 }) {
                    if (this.examManager.getExamAnswers()[index] !== -1) {
                      Text(`您的答案：${question.options[this.examManager.getExamAnswers()[index]]}`)
                        .fontSize(12)
                        .fontColor('#ef4444')
                        .width('100%')
                        .textAlign(TextAlign.Start)
                    }
                    Text(`正确答案：${question.options[question.correctAnswer]}`)
                      .fontSize(12)
                      .fontColor('#22c55e')
                      .width('100%')
                      .textAlign(TextAlign.Start)
                    Text(`解析：${question.explanation}`)
                      .fontSize(12)
                      .fontColor($r('app.color.text_tertiary'))
                      .width('100%')
                      .textAlign(TextAlign.Start)
                  }
                  .width('100%')
                }
              }
              .padding(15)
              .width('100%')
              .backgroundColor('#101e1e1e')
              .border({ 
                width: 1, 
                color: this.examManager.getExamAnswers()[index] === question.correctAnswer ? '#22c55e' : '#ef4444', 
                radius: 8 
              })
            })
          }
          .width('100%')
        }

        // 底部按钮
        Column({ space: 10 }) {
          if (this.isPassed) {
            Button('进入应用', { type: ButtonType.Normal })
              .fontSize(FontSizeManager.getScaledFontSize(15))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.background_primary'))
              .backgroundColor('#22c55e')
              .onClick(() => this.enterApp())
              .borderRadius(8)
              .width('100%')
              .padding({ top: 12, bottom: 12 })
          } else {
            Button('重新考试', { type: ButtonType.Normal })
              .fontSize(FontSizeManager.getScaledFontSize(15))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.background_primary'))
              .backgroundColor('#3698d9')
              .onClick(() => this.restartExam())
              .borderRadius(8)
              .width('100%')
              .padding({ top: 12, bottom: 12 })
          }

          if (this.isPassed) {
            Button('重新考试', { type: ButtonType.Normal })
              .fontSize(14)
              .fontColor('#3698d9')
              .backgroundColor('transparent')
              .border({ width: 1, color: '#3698d9', radius: 6 })
              .onClick(() => this.restartExam())
              .width('100%')
              .padding({ top: 10, bottom: 10 })
          }
        }
        .width('100%')
      }
      .padding({ top: 20, bottom: 20, left: 20, right: 20 })
      .width('100%')
    }
    .width('80%')
    .height('95%')
  }
}