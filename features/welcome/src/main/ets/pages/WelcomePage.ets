import { PreferencesUtil } from "utils"
import { Exam } from "../view/Exam";
import { Guide } from "../view/Guide";
import { Instruction } from "../view/Instruction";
import { Knowledge } from "../view/Knowledge";
import { Result } from "../view/Result";

interface Question {
  id: number;
  question: string;
  options: string[];
  correctAnswer: number;
  explanation: string;
}

@ComponentV2
export struct WelcomePage {
  @Consumer('ac')isApproved: boolean = false

  @Provider('sc')swiperController: SwiperController = new SwiperController();
  @Provider('currentQuestion') currentQuestion: number = 0
  @Provider('timeLeft') timeLeft: number = 300 // 5分钟 = 300秒
  @Provider('timer') timer?: number
  @Provider('navScroller') navScroller: Scroller = new Scroller()

  // 考试题目
  @Provider('questions') questions: Question[] = [
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
  
  // 考试相关状态管理
  @Provider('examScore') examScore: number = 0
  @Provider('examAnswers') examAnswers: number[] = []
  @Provider('examCompleted') examCompleted: boolean = false
  @Provider('examStart') examStart: boolean = false

  startExam() {
    this.currentQuestion = 0
    this.timeLeft = 300
    this.examAnswers = new Array(this.questions.length).fill(-1)
    this.startTimer()
  }

  startTimer() {
    this.timer = setInterval(() => {
      this.timeLeft--
      if (this.timeLeft <= 0) {
        this.submitExam()
      }
    }, 1000)
  }

  submitExam() {
    this.stopTimer()
    this.examScore = this.calculateScore()
    this.examCompleted = true
    this.swiperController?.showNext()
  }

  stopTimer() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = undefined
    }
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