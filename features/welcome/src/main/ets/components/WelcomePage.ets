/*
 * SCP基金会准入考试页面
 * 基于鸿蒙ArkTS和ArkUI框架实现
 * 适配API Version 17
 */

import { router } from '@kit.core';

@Component
export struct WelcomePage {
  // 当前步骤：0-intro, 1-knowledge, 2-exam_instructions, 3-exam, 4-results
  @State currentStep: number = 0;
  
  // 考试答案记录
  @State examAnswers: Record<string, number> = {};
  
  // 当前题目索引
  @State currentQuestionIndex: number = 0;
  
  // 考试得分
  @State examScore: number = 0;
  
  // 是否显示结果
  @State showResults: boolean = false;
  
  // 考试剩余时间（秒）
  @State timeLeft: number = 300; // 5分钟
  
  // 考试是否开始
  @State examStarted: boolean = false;
  
  // 计时器ID
  private timerId: number = -1;
  
  // 考试题目
  private examQuestions: Array<ExamQuestion> = [
    {
      id: 'foundation_purpose',
      question: 'SCP基金会的主要使命是什么？',
      options: [
        '消灭所有异常现象',
        '收容、控制、保护异常现象',
        '公开展示异常现象',
        '利用异常现象获取利益'
      ],
      correctAnswer: 1,
      points: 10,
      explanation: 'SCP基金会的座右铭是"收容、控制、保护"（Secure, Contain, Protect）'
    },
    {
      id: 'safe_class',
      question: 'Safe级收容等级表示什么？',
      options: [
        '该异常完全无害',
        '该异常容易理解和收容',
        '该异常对人类安全',
        '该异常已被销毁'
      ],
      correctAnswer: 1,
      points: 10,
      explanation: 'Safe级并不表示无害，而是表示容易理解和收容的异常'
    },
    {
      id: 'euclid_class',
      question: 'Euclid级异常的特点是什么？',
      options: [
        '极其危险且难以收容',
        '完全可预测的行为',
        '需要复杂程序来维持收容',
        '已经失控的异常'
      ],
      correctAnswer: 2,
      points: 10,
      explanation: 'Euclid级异常需要更复杂的收容程序，行为不完全可预测'
    },
    {
      id: 'keter_class',
      question: 'Keter级异常代表什么？',
      options: [
        '最容易收容的异常',
        '对基金会有益的异常',
        '极难收容且高度危险的异常',
        '已经被解释的异常'
      ],
      correctAnswer: 2,
      points: 10,
      explanation: 'Keter级是最高危险等级，表示极难收容且对人类存在重大威胁'
    },
    {
      id: 'thaumiel_class',
      question: 'Thaumiel级异常有什么特殊用途？',
      options: [
        '用于攻击敌人',
        '用于收容其他异常',
        '用于娱乐目的',
        '用于科学实验'
      ],
      correctAnswer: 1,
      points: 10,
      explanation: 'Thaumiel级异常被基金会用来收容或对抗其他异常'
    },
    {
      id: 'scp_number',
      question: 'SCP编号的正确格式是什么？',
      options: [
        'SCP-XXX（三位数字）',
        'SCP-XXXX（四位数字）',
        'SCP-XX（两位数字）',
        '以上都可以'
      ],
      correctAnswer: 3,
      points: 10,
      explanation: 'SCP编号可以是2-4位数字，最常见的是3位数字格式'
    },
    {
      id: 'foundation_secrecy',
      question: '为什么基金会要保持秘密？',
      options: [
        '为了垄断异常现象',
        '避免引起公众恐慌和社会动荡',
        '为了获得更多资金',
        '法律要求必须保密'
      ],
      correctAnswer: 1,
      points: 10,
      explanation: '基金会保持秘密是为了维护正常社会秩序，避免异常知识造成恐慌'
    },
    {
      id: 'anomalous_object',
      question: '什么是异常物品？',
      options: [
        '普通的科学实验器材',
        '违反已知科学定律的物品、实体或现象',
        '古代的历史文物',
        '外星人的科技产品'
      ],
      correctAnswer: 1,
      points: 10,
      explanation: '异常是指违反已知科学定律和人类理解的现象、实体或物品'
    },
    {
      id: 'cross_reference',
      question: 'SCP文档中的交叉引用有什么作用？',
      options: [
        '装饰文档内容',
        '展示其他相关的SCP异常',
        '增加文档长度',
        '混淆读者视线'
      ],
      correctAnswer: 1,
      points: 10,
      explanation: '交叉引用帮助读者了解相关的其他异常，构建完整的SCP世界观'
    },
    {
      id: 'fictional_nature',
      question: 'SCP基金会的本质是什么？',
      options: [
        '真实存在的秘密组织',
        '虚构的创意写作项目',
        '政府的秘密部门',
        '外星人建立的组织'
      ],
      correctAnswer: 1,
      points: 10,
      explanation: 'SCP基金会是一个虚构的创意写作项目，所有内容都是文学创作'
    }
  ];

  // 组件销毁时清理定时器
  aboutToDisappear() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  // 计算考试得分
  private calculateScore() {
    let score = 0;
    for (let i = 0; i < this.examQuestions.length; i++) {
      const question = this.examQuestions[i];
      const answerIndex = this.examAnswers[question.id];
      if (answerIndex !== undefined && answerIndex === question.correctAnswer) {
        score += question.points;
      }
    }
    this.examScore = score;
    this.showResults = true;
  }

  // 处理考试答案
  private handleExamAnswer(questionId: string, answerIndex: number) {
    this.examAnswers = {
      ...this.examAnswers,
      [questionId]: answerIndex
    };
  }

  // 处理下一步
  private handleNext() {
    if (this.currentStep === 3) { // Exam step
      this.calculateScore();
      this.currentStep = 4;
    } else if (this.currentStep === 4) { // Results step
      if (this.examScore >= 80) {
        // 考试通过，进入主应用
        router.replace({
          url: 'pages/MainPage'
        });
      } else {
        // 考试未通过，关闭应用
        console.log('考试未通过，无法进入应用');
      }
    } else {
      this.currentStep = this.currentStep + 1;
    }
  }

  // 开始考试
  private handleStartExam() {
    this.currentStep = 3;
    this.examStarted = true;
    this.timeLeft = 300;
    // 启动计时器
    this.startTimer();
  }

  // 启动计时器
  private startTimer() {
    // 在ArkTS中，我们使用setInterval来实现计时器
    this.timerId = setInterval(() => {
      if (this.examStarted && this.timeLeft > 0 && this.currentStep === 3) {
        this.timeLeft = this.timeLeft - 1;
      } else if (this.timeLeft === 0 && this.currentStep === 3) {
        // 时间到，自动提交考试
        clearInterval(this.timerId);
        this.timerId = -1;
        this.calculateScore();
        this.currentStep = 4;
      }
    }, 1000) as unknown as number;
  }

  // 下一题
  private handleNextQuestion() {
    if (this.currentQuestionIndex < this.examQuestions.length - 1) {
      this.currentQuestionIndex = this.currentQuestionIndex + 1;
    }
  }

  // 上一题
  private handlePrevQuestion() {
    if (this.currentQuestionIndex > 0) {
      this.currentQuestionIndex = this.currentQuestionIndex - 1;
    }
  }

  // 格式化时间
  private formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }

  build() {
    Column() {
      // 步骤指示器
      this.renderStepIndicator();
      
      // 根据当前步骤渲染不同页面
      this.renderCurrentStep();
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1e1e1e')
  }

  // 渲染步骤指示器
  private renderStepIndicator() {
    Row() {
      ForEach(['介绍', '知识', '说明', '考试', '结果'], (step: string, index: number) => {
        Column() {
          Circle({ width: 20, height: 20 })
            .fillColor(index === this.currentStep ? '#ff4444' : (index < this.currentStep ? '#00cc66' : '#666666'))
          
          Text(step)
            .fontSize(12)
            .fontColor(index === this.currentStep ? '#ffffff' : '#aaaaaa')
            .margin({ top: 5 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }, item => item)
    }
    .width('100%')
    .height(60)
    .backgroundColor('#2d2d2d')
    .padding({ left: 20, right: 20 })
  }

  // 渲染当前步骤
  private renderCurrentStep() {
    switch (this.currentStep) {
      case 0:
        this.renderIntro();
        break;
      case 1:
        this.renderKnowledge();
        break;
      case 2:
        this.renderExamInstructions();
        break;
      case 3:
        this.renderExam();
        break;
      case 4:
        this.renderResults();
        break;
      default:
        this.renderIntro();
        break;
    }
  }

  // 渲染介绍页面
  private renderIntro() {
    // 实现介绍页面
    Column() {
      Text('欢迎来到SCP基金会')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ff4444')
        .margin({ bottom: 20 })
      
      Text('异常物品收容与研究组织')
        .fontSize(18)
        .fontColor('#cccccc')
        .margin({ bottom: 30 })
      
      Text('在您访问我们的数据库之前，需要通过基础准入考试。\n\n考试将测试您对SCP基金会基本知识的掌握程度，包括：\n- 基金会的使命与组织结构\n- 异常物品的分类与收容\n- 相关术语与概念\n\n考试时间为5分钟，及格分数为80分。')
        .fontSize(14)
        .fontColor('#aaaaaa')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 30 })
      
      Button('开始学习')
        .width('80%')
        .onClick(() => {
          this.handleNext();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // 渲染知识学习页面
  private renderKnowledge() {
    // 实现知识学习页面
    Column() {
      Text('SCP基金会基础知识')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4a90e2')
        .margin({ bottom: 20 })
      
      Text('基金会简介')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#cccccc')
        .margin({ bottom: 10 })
      
      Text('SCP基金会（Secure, Contain, Protect）是一个国际性秘密组织，致力于收容和研究各种异常物品、现象和实体。我们的使命是确保这些异常不会对人类社会造成威胁，同时保护人类免受其潜在危害。')
        .fontSize(14)
        .fontColor('#aaaaaa')
        .margin({ bottom: 20 })
      
      Text('收容等级系统')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#cccccc')
        .margin({ bottom: 10 })
      
      Text('Safe级：异常易于收容和理解\nEuclid级：异常行为不完全可预测，需要复杂收容程序\nKeter级：异常极难收容且高度危险\nThaumiel级：用于收容或对抗其他异常的特殊异常')
        .fontSize(14)
        .fontColor('#aaaaaa')
        .margin({ bottom: 20 })
      
      Text('重要概念')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#cccccc')
        .margin({ bottom: 10 })
      
      Text('D级人员：用于接触高危险异常的死刑犯\n机动特遣队：专门处理特定异常或威胁的专家团队\n交叉引用：文档中指向其他相关SCP项目的链接')
        .fontSize(14)
        .fontColor('#aaaaaa')
        .margin({ bottom: 30 })
      
      Button('我已理解，继续下一步')
        .width('80%')
        .onClick(() => {
          this.handleNext();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 20, right: 20 })
    .scrollable(true)
  }

  // 渲染考试说明页面
  private renderExamInstructions() {
    // 实现考试说明页面
    Column() {
      Text('准入考试说明')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ff9900')
        .margin({ bottom: 20 })
      
      Text('考试规则')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#cccccc')
        .margin({ bottom: 10 })
      
      Text('1. 考试共10题，每题10分，满分100分\n2. 及格分数为80分\n3. 考试时间为5分钟\n4. 每题只能选择一个答案\n5. 考试结束后将显示成绩和错题解析')
        .fontSize(14)
        .fontColor('#aaaaaa')
        .margin({ bottom: 20 })
      
      Text('注意事项')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#cccccc')
        .margin({ bottom: 10 })
      
      Text('1. 考试期间请勿离开页面\n2. 时间到将自动提交试卷\n3. 考试未通过将无法访问应用\n4. 请认真作答，确保理解题目内容')
        .fontSize(14)
        .fontColor('#aaaaaa')
        .margin({ bottom: 30 })
      
      Button('我已准备好，开始考试')
        .width('80%')
        .onClick(() => {
          this.handleStartExam();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 20, right: 20 })
  }

  // 渲染考试页面
  private renderExam() {
    // 实现考试页面
    Column() {
      // 标题
      Text('SCP基金会准入考试')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ff4444')
        .margin({ bottom: 10 })
      
      // 进度和时间
      Row() {
        Text(`第 ${this.currentQuestionIndex + 1} 题 / 共 ${this.examQuestions.length} 题`)
          .fontSize(14)
          .fontColor('#cccccc')
          .layoutWeight(1)
        
        Text(`剩余时间: ${this.formatTime(this.timeLeft)}`)
          .fontSize(14)
          .fontColor('#ff9900')
      }
      .width('90%')
      .margin({ bottom: 20 })
      
      // 题目
      if (this.examQuestions.length > 0 && this.currentQuestionIndex < this.examQuestions.length) {
        const currentQuestion = this.examQuestions[this.currentQuestionIndex];
        
        Text(currentQuestion.question)
          .fontSize(18)
          .fontColor('#ffffff')
          .margin({ bottom: 20 })
        
        // 选项
        ForEach(currentQuestion.options, (option: string, index: number) => {
          Row() {
            Radio({ value: index.toString(), group: `question_${currentQuestion.id}` })
              .checked(this.examAnswers[currentQuestion.id] === index)
              .onChange((isChecked: boolean) => {
                if (isChecked) {
                  this.handleExamAnswer(currentQuestion.id, index);
                }
              })
            
            Text(option)
              .fontSize(16)
              .fontColor('#cccccc')
              .layoutWeight(1)
              .margin({ left: 10 })
          }
          .width('100%')
          .margin({ bottom: 10 })
        }, item => item)
        
        // 导航按钮
        Row() {
          Button('上一题')
            .enabled(this.currentQuestionIndex > 0)
            .onClick(() => {
              this.handlePrevQuestion();
            })
          
          Button('下一题')
            .enabled(this.currentQuestionIndex < this.examQuestions.length - 1)
            .onClick(() => {
              this.handleNextQuestion();
            })
          
          Button('提交考试')
            .enabled(this.currentQuestionIndex === this.examQuestions.length - 1)
            .onClick(() => {
              this.handleNext();
            })
        }
        .width('90%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 20 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 20, right: 20 })
  }

  // 渲染结果页面
  private renderResults() {
    const passed = this.examScore >= 80;
    
    Column() {
      Text(passed ? '考试通过！' : '考试未通过')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(passed ? '#00cc66' : '#ff3333')
        .margin({ bottom: 10 })
      
      Text(`您的得分: ${this.examScore} / 100`)
        .fontSize(18)
        .fontColor('#cccccc')
        .margin({ bottom: 20 })
      
      // 显示错题解析
      if (!passed || this.examScore < 100) {
        Text('错题解析:')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ff9900')
          .margin({ bottom: 10 })
        
        // 遍历所有题目，显示答错的题目解析
        ForEach(this.examQuestions, (question: ExamQuestion, index: number) => {
          const userAnswer = this.examAnswers[question.id];
          const isCorrect = userAnswer === question.correctAnswer;
          
          if (!isCorrect) {
            Column() {
              Text(`题目 ${index + 1}: ${question.question}`)
                .fontSize(16)
                .fontColor('#ffffff')
                .margin({ bottom: 5 })
              
              Text(`您的答案: ${question.options[userAnswer]}`)
                .fontSize(14)
                .fontColor('#ff6666')
                .margin({ bottom: 5 })
              
              Text(`正确答案: ${question.options[question.correctAnswer]}`)
                .fontSize(14)
                .fontColor('#00cc66')
                .margin({ bottom: 5 })
              
              if (question.explanation) {
                Text(`解析: ${question.explanation}`)
                  .fontSize(14)
                  .fontColor('#aaaaaa')
              }
            }
            .width('100%')
            .margin({ bottom: 15 })
          }
        }, item => item.id)
      }
      
      Text(passed ? '欢迎加入SCP基金会数据库' : '很遗憾，您暂时无法访问应用')
        .fontSize(16)
        .fontColor('#cccccc')
        .margin({ bottom: 30 })
      
      Button(passed ? '进入应用' : '关闭应用')
        .width('80%')
        .onClick(() => {
          this.handleNext();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 20, right: 20 })
    .scrollable(true)
  }
}

// 考试题目接口
interface ExamQuestion {
  id: string;
  question: string;
  options: string[];
  correctAnswer: number;
  points: number;
  explanation?: string;
}