import { FontSizeManager, PreferencesUtil } from "utils"

interface Question {
  id: number;
  question: string;
  options: string[];
  correctAnswer: number;
  explanation: string;
}

@ComponentV2
export struct Result {
  @Consumer('sc') swiperController?: SwiperController
  @Consumer('examScore') examScore: number = 0
  @Consumer('examAnswers') examAnswers: number[] = []
  @Consumer('examCompleted') examCompleted: boolean = false
  @Consumer('ac')isApproved: boolean = false
  @Consumer('questions') questions: Question[] = [
    {
      id: 1,
      question: "SCP基金会的三大核心使命是什么？",
      options: ["收容、控制、保护", "安全、控制、程序", "秘密、收容、保护", "安全、收容、程序"],
      correctAnswer: 0,
      explanation: "SCP基金会的使命是Secure（收容）、Contain（控制）、Protect（保护）异常现象。"
    },
    {
      id: 2,
      question: "Safe级收容等级表示什么？",
      options: ["完全无害的异常", "容易理解和收容的异常", "安全的异常物品", "已被销毁的异常"],
      correctAnswer: 1,
      explanation: "Safe级表示容易理解和收容的异常，不等于无害，而是指可预测且容易控制。"
    },
    {
      id: 3,
      question: "Keter级异常的特点是什么？",
      options: ["对基金会有益", "需要复杂收容程序", "极难收容且高度危险", "已被完全理解"],
      correctAnswer: 2,
      explanation: "Keter级异常极难收容且高度危险，对人类文明构成严重威胁。"
    },
    {
      id: 4,
      question: "Thaumiel级异常的特殊之处在于？",
      options: ["无法收容", "被基金会用来对抗其他异常", "来自外太空", "具有时间异常"],
      correctAnswer: 1,
      explanation: "Thaumiel级异常被基金会用来收容或对抗其他异常，对基金会有益。"
    },
    {
      id: 5,
      question: "SCP编号的标准格式是什么？",
      options: ["SCP-XXX", "SCF-XXX", "SPC-XXX", "SCP_XXX"],
      correctAnswer: 0,
      explanation: "SCP编号通常为SCP-XXX格式，其中XXX是2-4位数字。"
    },
    {
      id: 6,
      question: "Euclid级异常需要什么样的收容措施？",
      options: ["简单的物理收容", "复杂的收容程序", "无需收容", "立即销毁"],
      correctAnswer: 1,
      explanation: "Euclid级异常需要复杂程序来维持收容，行为模式不完全可预测。"
    },
    {
      id: 7,
      question: "基金会保持秘密的主要原因是？",
      options: ["保护商业机密", "维护社会稳定", "避免政府干预", "保护员工隐私"],
      correctAnswer: 1,
      explanation: "基金会必须保持秘密以维护社会正常秩序和稳定。"
    },
    {
      id: 8,
      question: "什么是收容失效？",
      options: ["收容设施损坏", "异常脱离收容状态", "收容程序过期", "收容成本过高"],
      correctAnswer: 1,
      explanation: "收容失效是指异常脱离收容状态，可能对外界造成威胁。"
    },
    {
      id: 9,
      question: "SCP基金会在现实中是什么？",
      options: ["真实存在的组织", "政府秘密部门", "虚构的创意写作项目", "科学研究机构"],
      correctAnswer: 2,
      explanation: "SCP基金会完全是虚构的创意写作项目，所有内容都是文学创作。"
    },
    {
      id: 10,
      question: "异常现象的定义是什么？",
      options: ["罕见的自然现象", "违反已知科学定律的现象", "未被发现的科学现象", "人造的特殊物品"],
      correctAnswer: 1,
      explanation: "异常是指违反已知科学定律和人类理解的现象、实体或物品。"
    }
  ]
  @Consumer('currentQuestion') currentQuestion: number = 0
  @Consumer('timeLeft') timeLeft: number = 300 // 5分钟 = 300秒
  @Consumer('navScroller') navScroller: Scroller = new Scroller()

  @Local showDetails: boolean = false

  get isPassed(): boolean {
    return this.examScore >= 80
  }

  get correctCount(): number {
    return this.examAnswers.filter((answer, index) => answer === this.questions[index].correctAnswer).length
  }

  get answeredCount(): number {
    return this.examAnswers.filter(answer => answer !== -1).length
  }

  async restartExam() {
    // 重置考试状态
    this.examScore = 0
    this.examAnswers = []
    this.examCompleted = false
    this.isApproved = false
    this.currentQuestion = 0
    this.navScroller.scrollToIndex(0, true, ScrollAlign.CENTER)
    this.timeLeft = 300// 跳转到第一个页面（Guide）
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
    if (this.examCompleted) {
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
            Text(`${this.examScore}/100`)
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
            Text(`${this.answeredCount}/${this.questions.length} 题`)
              .fontSize(14)
              .fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')

          Row() {
            Text('正确题数')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text(`${this.correctCount}/${this.questions.length} 题`)
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

            ForEach(this.questions, (question: Question, index: number) => {
              Column({ space: 10 }) {
                Row() {
                  Text(`第${index + 1}题`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Blank()
                  Text(this.examAnswers[index] === question.correctAnswer ? '正确' : '错误')
                    .fontSize(12)
                    .fontColor(this.examAnswers[index] === question.correctAnswer ? '#22c55e' : '#ef4444')
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .backgroundColor(this.examAnswers[index] === question.correctAnswer ? '#1022c55e' : '#10ef4444')
                    .borderRadius(4)
                }
                .width('100%')

                Text(question.question)
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')
                  .textAlign(TextAlign.Start)

                if (this.examAnswers[index] !== question.correctAnswer) {
                  Column({ space: 5 }) {
                    if (this.examAnswers[index] !== -1) {
                      Text(`您的答案：${question.options[this.examAnswers[index]]}`)
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
                color: this.examAnswers[index] === question.correctAnswer ? '#22c55e' : '#ef4444', 
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