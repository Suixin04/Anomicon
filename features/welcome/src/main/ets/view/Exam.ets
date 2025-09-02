import { FontSizeManager } from "utils"

interface Question {
  id: number;
  question: string;
  options: string[];
  correctAnswer: number;
  explanation: string;
}

@ComponentV2
export struct Exam {
  @Consumer('sc') swiperController?: SwiperController
  @Consumer('examScore') examScore: number = 0
  @Consumer('examAnswers') examAnswers: number[] = []
  @Consumer('examCompleted') examCompleted: boolean = false
  @Consumer('examStart') examStart: boolean = false

  @Consumer('currentQuestion') currentQuestion: number = 0
  @Consumer('timeLeft') timeLeft: number = 300 // 5分钟 = 300秒
  @Consumer('timer') timer?: number
  @Consumer('navScroller') navScroller: Scroller = new Scroller()

  // 考试题目
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

  stopTimer() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = undefined
    }
  }

  formatTime(seconds: number): string {
    const minutes = Math.floor(seconds / 60)
    const remainingSeconds = seconds % 60
    return `${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`
  }

  selectAnswer(questionIndex: number, answerIndex: number) {
    this.examAnswers[questionIndex] = answerIndex
  }

  calculateScore(): number {
    let score = 0
    this.examAnswers.forEach((answer, index) => {
      if (answer === this.questions[index].correctAnswer) {
        score += 10
      }
    })
    return score
  }

  submitExam() {
    this.stopTimer()
    this.examScore = this.calculateScore()
    this.examCompleted = true
    this.swiperController?.showNext()
  }

  nextQuestion() {
    if (this.currentQuestion < this.questions.length - 1) {
      this.currentQuestion++
      this.navScroller.scrollToIndex(this.currentQuestion, true, ScrollAlign.CENTER)
    }
  }

  prevQuestion() {
    if (this.currentQuestion > 0) {
      this.currentQuestion--
      this.navScroller.scrollToIndex(this.currentQuestion, true, ScrollAlign.CENTER)
    }
  }

  goToQuestion(index: number) {
    this.currentQuestion = index
    this.navScroller.scrollToIndex(index, true, ScrollAlign.CENTER)
  }

  aboutToDisappear() {
    this.stopTimer()
  }

  build() {
    Column({ space: 20 }) {
      Row() {
        Column({ space: 5 }) {
          Text(`题目 ${this.currentQuestion + 1}/${this.questions.length}`)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3698d9')
          Text(`剩余时间: ${this.formatTime(this.timeLeft)}`)
            .fontSize(12)
            .fontColor(this.timeLeft <= 60 ? '#ef4444' : $r('app.color.text_tertiary'))
        }.alignItems(HorizontalAlign.Start)

        Blank()

        Text(`${this.examAnswers.filter(a => a !== -1).length}/${this.questions.length} 已答`)
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
        .width('100%')
        .padding({ bottom: 10 })

      // 进度条
      Progress({
        value: this.currentQuestion + 1,
        total: this.questions.length,
        type: ProgressType.Linear
      })
        .width('100%')
        .color('#3698d9')
        .backgroundColor('#20ffffff')

      // 当前题目
      Column({ space: 15 }) {
        Text(this.questions[this.currentQuestion].question)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Start)
          .width('100%')

        Column({ space: 10 }) {
          ForEach(this.questions[this.currentQuestion].options, (option: string, index: number) => {
            Row({ space: 12 }) {
              Radio({ value: `option_${index}`, group: `question_${this.currentQuestion}` })
                .checked(this.examAnswers[this.currentQuestion] === index)
                .onChange(() => this.selectAnswer(this.currentQuestion, index))
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
            .backgroundColor(this.examAnswers[this.currentQuestion] === index ? '#103698d9' : '#101e1e1e')
            .border({
              width: 1,
              color: this.examAnswers[this.currentQuestion] === index ? '#3698d9' : '#20ffffff',
              radius: 8
            })
            .onClick(() => this.selectAnswer(this.currentQuestion, index))
          })
        }
      }
        .layoutWeight(1)
        .width('100%')

      // 题目导航
      Row({ space: 8 }) {
        List({ scroller: this.navScroller }) {
          ForEach(this.questions, (question: Question, index: number) => {
            ListItem() {
              Text((index + 1).toString())
                .fontSize(12)
                .fontColor(this.currentQuestion === index ? $r('app.color.background_primary') :
                         this.examAnswers[index] !== -1 ? '#3698d9' : $r('app.color.text_tertiary'))
                .width(32)
                .height(32)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.currentQuestion === index ? '#3698d9' :
                               this.examAnswers[index] !== -1 ? '#103698d9' : '#101e1e1e')
                .border({
                  width: 1,
                  color: this.currentQuestion === index ? '#3698d9' :
                         this.examAnswers[index] !== -1 ? '#3698d9' : '#20ffffff',
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
        if (this.currentQuestion > 0) {
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

        if (this.currentQuestion < this.questions.length - 1) {
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