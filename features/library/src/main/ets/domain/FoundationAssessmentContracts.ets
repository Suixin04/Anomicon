import { LibraryContentRef } from './LibraryContentRef';

/** Icon semantics for the curated RAISA assessment subjects. */
export enum FoundationAssessmentIcon {
  LOCKBOX = 'lockbox',
  TASK_FORCE = 'task_force',
  CRV = 'crv'
}

/** Normalize exam identifiers so lookups tolerate whitespace and case variations. */
export function normalizeAssessmentExamId(raw: string): string {
  return raw.trim().toLowerCase();
}

/** Single immersive RAISA dispatch question with optional revealable hidden clue. */
export class FoundationAssessmentQuestion {
  readonly id: string;
  readonly dispatchCode: string;
  readonly dispatchTag: string;
  readonly briefing: string;
  readonly hiddenClue: string;
  readonly hiddenClueMaskHint: string;
  readonly prompt: string;
  readonly options: string[];
  readonly correctIndex: number;
  readonly explanation: string;
  readonly reference: LibraryContentRef;
  readonly referenceLabel: string;

  constructor(
    id: string,
    dispatchCode: string,
    dispatchTag: string,
    briefing: string,
    prompt: string,
    options: string[],
    correctIndex: number,
    explanation: string,
    reference: LibraryContentRef,
    referenceLabel: string,
    hiddenClue: string = '',
    hiddenClueMaskHint: string = ''
  ) {
    this.id = id;
    this.dispatchCode = dispatchCode;
    this.dispatchTag = dispatchTag;
    this.briefing = briefing;
    this.hiddenClue = hiddenClue;
    this.hiddenClueMaskHint = hiddenClueMaskHint;
    this.prompt = prompt;
    this.options = options;
    this.correctIndex = correctIndex;
    this.explanation = explanation;
    this.reference = reference;
    this.referenceLabel = referenceLabel;
  }

  hasHiddenClue(): boolean {
    return this.hiddenClue.trim().length > 0;
  }
}

/** Curated multi-question RAISA assessment module. */
export class FoundationAssessmentExam {
  readonly id: string;
  readonly code: string;
  readonly title: string;
  readonly subtitle: string;
  readonly sealTitle: string;
  readonly recommendedRank: string;
  readonly icon: FoundationAssessmentIcon;
  readonly passScore: number;
  readonly xpReward: number;
  readonly passRemark: string;
  readonly failRemark: string;
  readonly questions: FoundationAssessmentQuestion[];

  constructor(
    id: string,
    code: string,
    title: string,
    subtitle: string,
    sealTitle: string,
    recommendedRank: string,
    icon: FoundationAssessmentIcon,
    passScore: number,
    xpReward: number,
    passRemark: string,
    failRemark: string,
    questions: FoundationAssessmentQuestion[]
  ) {
    this.id = normalizeAssessmentExamId(id);
    this.code = code;
    this.title = title;
    this.subtitle = subtitle;
    this.sealTitle = sealTitle;
    this.recommendedRank = recommendedRank;
    this.icon = icon;
    this.passScore = passScore;
    this.xpReward = xpReward;
    this.passRemark = passRemark;
    this.failRemark = failRemark;
    this.questions = questions;
  }
}

/** Persistent per-exam record stored in local SQLite. */
export class FoundationAssessmentRecord {
  readonly examId: string;
  readonly passed: boolean;
  readonly bestScore: number;
  readonly totalQuestions: number;
  readonly attempts: number;
  readonly xpAwarded: number;
  readonly passedAt: number;
  readonly updatedAt: number;

  constructor(
    examId: string,
    passed: boolean,
    bestScore: number,
    totalQuestions: number,
    attempts: number,
    xpAwarded: number,
    passedAt: number,
    updatedAt: number
  ) {
    this.examId = normalizeAssessmentExamId(examId);
    this.passed = passed === true;
    this.bestScore = Math.max(0, Math.floor(bestScore));
    this.totalQuestions = Math.max(1, Math.floor(totalQuestions));
    this.attempts = Math.max(0, Math.floor(attempts));
    this.xpAwarded = Math.max(0, Math.floor(xpAwarded));
    this.passedAt = Math.max(0, Math.floor(passedAt));
    this.updatedAt = Math.max(0, Math.floor(updatedAt));
  }
}

/** Outcome returned by ViewModel after evaluating and persisting one completed exam. */
export class FoundationAssessmentSubmissionResult {
  readonly exam: FoundationAssessmentExam;
  readonly record: FoundationAssessmentRecord;
  readonly score: number;
  readonly totalQuestions: number;
  readonly passed: boolean;
  readonly newlyPassed: boolean;
  readonly awardedXpNow: number;

  constructor(
    exam: FoundationAssessmentExam,
    record: FoundationAssessmentRecord,
    score: number,
    totalQuestions: number,
    passed: boolean,
    newlyPassed: boolean,
    awardedXpNow: number
  ) {
    this.exam = exam;
    this.record = record;
    this.score = score;
    this.totalQuestions = totalQuestions;
    this.passed = passed;
    this.newlyPassed = newlyPassed;
    this.awardedXpNow = awardedXpNow;
  }
}

/** Read-only badge seal projection rendered on the Foundation hub and Terminal card. */
export class FoundationAssessmentSealSummary {
  readonly examId: string;
  readonly code: string;
  readonly sealTitle: string;
  readonly icon: FoundationAssessmentIcon;
  readonly passed: boolean;
  readonly xpReward: number;
  readonly bestScore: number;
  readonly totalQuestions: number;

  constructor(
    examId: string,
    code: string,
    sealTitle: string,
    icon: FoundationAssessmentIcon,
    passed: boolean,
    xpReward: number,
    bestScore: number,
    totalQuestions: number
  ) {
    this.examId = examId;
    this.code = code;
    this.sealTitle = sealTitle;
    this.icon = icon;
    this.passed = passed;
    this.xpReward = xpReward;
    this.bestScore = bestScore;
    this.totalQuestions = totalQuestions;
  }
}

/** Persistence port for RAISA assessment certification records. */
export interface FoundationAssessmentRepository {
  listRecords(): Promise<FoundationAssessmentRecord[]>;
  saveRecord(record: FoundationAssessmentRecord): Promise<FoundationAssessmentRecord>;
  totalAwardedXp(): Promise<number>;
}
