import {
  FoundationAssessmentExam,
  FoundationAssessmentRecord,
  FoundationAssessmentRepository,
  FoundationAssessmentSealSummary,
  FoundationAssessmentSubmissionResult,
  normalizeAssessmentExamId
} from '../../domain/FoundationAssessmentContracts';
import {
  findFoundationAssessmentExam,
  listFoundationAssessmentExams,
  totalFoundationAssessmentXp
} from '../../domain/FoundationAssessmentCatalog';

export type FoundationAssessmentViewModelListener = () => void;
export type AssessmentBonusXpCallback = () => Promise<void>;
export type AssessmentNowProvider = () => number;

/**
 * Shared application-level state for Foundation RAISA assessments & badge seals.
 * Persists first-pass XP in SQLite and triggers immediate ResearchProfile reload.
 */
@ObservedV2
export class FoundationAssessmentViewModel {
  @Trace revision: number = 0;
  @Trace loading: boolean = false;
  @Trace error: string = '';
  @Trace profileRefreshError: string = '';
  @Trace initialized: boolean = false;

  private readonly repository: FoundationAssessmentRepository;
  private readonly onBonusXpAwarded: AssessmentBonusXpCallback | undefined;
  private readonly nowProvider: AssessmentNowProvider;
  private readonly recordsById: Map<string, FoundationAssessmentRecord> = new Map();
  private readonly listeners: FoundationAssessmentViewModelListener[] = [];
  private initialization: Promise<void> | undefined = undefined;
  private operationTail: Promise<void> = Promise.resolve();
  private disposed: boolean = false;

  constructor(
    repository: FoundationAssessmentRepository,
    onBonusXpAwarded?: AssessmentBonusXpCallback,
    nowProvider?: AssessmentNowProvider
  ) {
    this.repository = repository;
    this.onBonusXpAwarded = onBonusXpAwarded;
    this.nowProvider = nowProvider ?? ((): number => Date.now());
  }

  subscribe(listener: FoundationAssessmentViewModelListener): () => void {
    if (this.disposed) {
      return (): void => {};
    }
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
    return (): void => {
      const index = this.listeners.indexOf(listener);
      if (index >= 0) {
        this.listeners.splice(index, 1);
      }
    };
  }

  initialize(): Promise<void> {
    if (this.disposed || this.initialized) {
      return Promise.resolve();
    }
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    const task = this.enqueue(async (): Promise<void> => {
      this.loading = true;
      this.error = '';
      this.notifyListeners();
      try {
        const records = await this.repository.listRecords();
        if (this.disposed) {
          return;
        }
        this.replaceRecords(records);
        this.initialized = true;
      } catch (error) {
        if (!this.disposed) {
          this.error = error instanceof Error ? error.message : '读取资质考核记录失败';
        }
        throw error instanceof Error ? error : new Error('读取资质考核记录失败');
      } finally {
        if (!this.disposed) {
          this.loading = false;
          this.notifyListeners();
        }
      }
    });
    this.initialization = task;
    task.catch((): void => {
      if (this.initialization === task) {
        this.initialization = undefined;
      }
    });
    return task;
  }

  async reload(): Promise<void> {
    if (this.disposed) {
      return;
    }
    if (!this.initialized) {
      await this.initialize();
      return;
    }
    await this.enqueue(async (): Promise<void> => {
      this.loading = true;
      this.notifyListeners();
      try {
        const records = await this.repository.listRecords();
        if (this.disposed) {
          return;
        }
        this.replaceRecords(records);
        this.error = '';
      } catch (error) {
        if (!this.disposed) {
          this.error = error instanceof Error ? error.message : '读取资质考核记录失败';
        }
        throw error instanceof Error ? error : new Error('读取资质考核记录失败');
      } finally {
        if (!this.disposed) {
          this.loading = false;
          this.notifyListeners();
        }
      }
    });
  }

  dispose(): void {
    this.disposed = true;
    this.listeners.length = 0;
  }

  listExams(): FoundationAssessmentExam[] {
    return listFoundationAssessmentExams();
  }

  findExam(examId: string): FoundationAssessmentExam | undefined {
    return findFoundationAssessmentExam(examId);
  }

  recordFor(examId: string): FoundationAssessmentRecord | undefined {
    return this.recordsById.get(normalizeAssessmentExamId(examId));
  }

  sealSummaries(): FoundationAssessmentSealSummary[] {
    const exams = this.listExams();
    const summaries: FoundationAssessmentSealSummary[] = [];
    for (let index = 0; index < exams.length; index++) {
      const exam = exams[index];
      const record = this.recordsById.get(exam.id);
      summaries.push(new FoundationAssessmentSealSummary(
        exam.id,
        exam.code,
        exam.sealTitle,
        exam.icon,
        record !== undefined && record.passed,
        exam.xpReward,
        record !== undefined ? record.bestScore : 0,
        exam.questions.length
      ));
    }
    return summaries;
  }

  passedCount(): number {
    const exams = this.listExams();
    let count = 0;
    for (let index = 0; index < exams.length; index++) {
      const record = this.recordsById.get(exams[index].id);
      if (record !== undefined && record.passed) {
        count++;
      }
    }
    return count;
  }

  totalCount(): number {
    return this.listExams().length;
  }

  earnedXp(): number {
    const exams = this.listExams();
    let total = 0;
    for (let index = 0; index < exams.length; index++) {
      const record = this.recordsById.get(exams[index].id);
      if (record !== undefined) {
        total += record.xpAwarded;
      }
    }
    return total;
  }

  maxXp(): number {
    return totalFoundationAssessmentXp();
  }

  async submitAttempt(
    examId: string,
    rawScore: number
  ): Promise<FoundationAssessmentSubmissionResult> {
    const exam = findFoundationAssessmentExam(examId);
    if (exam === undefined) {
      throw new Error(`未找到资质考核科目：${examId}`);
    }
    if (!this.initialized) {
      await this.initialize();
    }
    const totalQuestions = exam.questions.length;
    const score = Math.max(0, Math.min(totalQuestions, Math.floor(rawScore)));
    const passedAttempt = score >= exam.passScore;
    let outcome: FoundationAssessmentSubmissionResult | undefined = undefined;
    let shouldReloadXp = false;

    await this.enqueue(async (): Promise<void> => {
      const existing = this.recordsById.get(exam.id);
      const now = this.nowProvider();
      const previouslyPassed = existing !== undefined && existing.passed;
      const previousXp = existing !== undefined ? existing.xpAwarded : 0;
      const nextPassed = previouslyPassed || passedAttempt;
      const newlyPassed = passedAttempt && !previouslyPassed;
      const awardedXpNow = passedAttempt && previousXp === 0 ? exam.xpReward : 0;
      const nextXpAwarded = previousXp + awardedXpNow;
      const nextBestScore = Math.max(existing !== undefined ? existing.bestScore : 0, score);
      const nextAttempts = (existing !== undefined ? existing.attempts : 0) + 1;
      const nextPassedAt = existing !== undefined && existing.passedAt > 0 ?
        existing.passedAt :
        (nextPassed ? now : 0);

      const saved = await this.repository.saveRecord(new FoundationAssessmentRecord(
        exam.id,
        nextPassed,
        nextBestScore,
        totalQuestions,
        nextAttempts,
        nextXpAwarded,
        nextPassedAt,
        now
      ));
      this.recordsById.set(saved.examId, saved);
      this.revision += 1;
      this.error = '';
      this.notifyListeners();

      shouldReloadXp = awardedXpNow > 0;
      outcome = new FoundationAssessmentSubmissionResult(
        exam,
        saved,
        score,
        totalQuestions,
        passedAttempt,
        newlyPassed,
        awardedXpNow
      );
    });

    if (shouldReloadXp) {
      // The award is durable. A profile read must never hold up or invalidate its receipt.
      this.refreshResearchProfile();
    }
    return outcome!;
  }

  async refreshResearchProfile(): Promise<void> {
    this.profileRefreshError = '';
    try {
      await this.onBonusXpAwarded?.();
      this.profileRefreshError = '';
    } catch (error) {
      this.profileRefreshError = error instanceof Error ? error.message : '档案阅历读取失败';
    }
  }

  private replaceRecords(records: FoundationAssessmentRecord[]): void {
    this.recordsById.clear();
    for (let index = 0; index < records.length; index++) {
      this.recordsById.set(records[index].examId, records[index]);
    }
    this.revision += 1;
  }

  private notifyListeners(): void {
    const snapshot = this.listeners.slice();
    for (let index = 0; index < snapshot.length; index++) {
      try {
        snapshot[index]();
      } catch (_error) {
      }
    }
  }

  private enqueue(operation: () => Promise<void>): Promise<void> {
    const next = this.operationTail.then(operation, operation);
    this.operationTail = next.catch((): void => {
    });
    return next;
  }
}
