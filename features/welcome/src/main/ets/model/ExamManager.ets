import { util } from '@kit.ArkTS';
import common from '@ohos.app.ability.common';

export interface Question {
  id: number;
  question: string;
  options: string[];
  correctAnswer: number;
  explanation: string;
}

// 单例考试管理器
@ObservedV2
export class ExamManager {
  private static instance: ExamManager;
  @Trace questions: Question[] = [];
  @Trace examAnswers: number[] = [];
  @Trace currentQuestion: number = 0;
  @Trace examScore: number = 0;
  @Trace examCompleted: boolean = false;
  @Trace examStart: boolean = false;

  private constructor() {
    // 私有构造函数，防止外部实例化
    this.loadQuestionsFromJSON();
  }

  // 获取单例实例
  public static getInstance(): ExamManager {
    if (!ExamManager.instance) {
      ExamManager.instance = new ExamManager();
    }
    return ExamManager.instance;
  }

  // 加载题目数据
  loadQuestionsFromJSON(): void {
    const context = getContext() as common.UIAbilityContext;
    context.resourceManager.getRawFileContent('ExamQuestions.json5').then((value: Uint8Array) => {
      const textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const content = textDecoder.decodeToString(value, { stream: false });
      const questions = JSON.parse(content) as Question[];
      
      if (questions && questions.length > 0) {
        this.questions = questions;
        this.examAnswers = new Array(this.questions.length).fill(-1);
        console.log('成功从JSON文件加载', this.questions.length, '道题目');
      }
    }).catch((error: Error) => {
      console.error('加载题目数据失败:', error);
    });
  }





  // 选择答案
  selectAnswer(questionIndex: number, answerIndex: number): void {
    if (this.examAnswers.length <= questionIndex) {
      this.examAnswers = [...this.examAnswers, ...new Array(questionIndex - this.examAnswers.length + 1).fill(-1)];
    }
    this.examAnswers[questionIndex] = answerIndex;
  }

  // 计算分数
  calculateScore(): number {
    let score = 0;
    this.examAnswers.forEach((answer, index) => {
      if (answer === this.questions[index].correctAnswer) {
        score += 10;
      }
    });
    this.examScore = score;
    return score;
  }

  // 提交考试
  submitExam(): void {
    this.calculateScore();
    this.examCompleted = true;
    this.examStart = false;
  }

  // 开始考试
  startExam(): void {
    this.currentQuestion = 0;
    this.examAnswers = new Array(this.questions.length).fill(-1);
    this.examStart = true;
    this.examCompleted = false;
    this.examScore = 0;
  }

  // 重置考试
  resetExam(): void {
    this.currentQuestion = 0;
    this.examAnswers = new Array(this.questions.length).fill(-1);
    this.examStart = false;
    this.examCompleted = false;
    this.examScore = 0;
  }

  // Getter方法
  getQuestions(): Question[] {
    return this.questions;
  }

  getExamAnswers(): number[] {
    return this.examAnswers;
  }

  getCurrentQuestion(): number {
    return this.currentQuestion;
  }

  setCurrentQuestion(index: number): void {
    this.currentQuestion = index;
  }

  getExamScore(): number {
    return this.examScore;
  }

  isExamCompleted(): boolean {
    return this.examCompleted;
  }

  isExamStarted(): boolean {
    return this.examStart;
  }

  getQuestionCount(): number {
    return this.questions.length;
  }

  // 获取当前题目
  getCurrentQuestionData(): Question | undefined {
    return this.questions[this.currentQuestion];
  }

  // 检查是否已回答所有题目
  isAllAnswered(): boolean {
    return this.examAnswers.every(answer => answer !== -1);
  }

  // 获取已回答题目数量
  getAnsweredCount(): number {
    return this.examAnswers.filter(answer => answer !== -1).length;
  }

  // 获取正确题目数量
  getCorrectCount(): number {
    return this.examAnswers.filter((answer, index) => 
      answer === this.questions[index].correctAnswer
    ).length;
  }
}