import {
  StorySeriesArticleContext,
  StorySeriesDefinition,
  StorySeriesEnrollment,
  StorySeriesEntry,
  StorySeriesProgressSnapshot,
  StorySeriesRepository,
  buildStorySeriesArticleContext,
  containsSeriesEntry,
  countSeriesProgress,
  findStorySeriesByHubId,
  findStorySeriesById,
  findStorySeriesByMemberId,
  listBuiltInStorySeries,
  normalizeSeriesPageId,
  resolveSeriesResumeEntry
} from '../../domain/StorySeriesContracts';
import { ReadingHistoryViewModel } from './ReadingHistoryViewModel';

export type StorySeriesViewModelListener = () => void;

/** Shared story series progress state synchronized with permanent read completion. */
@ObservedV2
export class StorySeriesViewModel {
  @Trace enrollments: StorySeriesEnrollment[] = [];
  @Trace enrolledCount: number = 0;
  @Trace stateRevision: number = 0;
  @Trace loading: boolean = false;
  @Trace error: string = '';
  @Trace initialized: boolean = false;

  private readonly repository: StorySeriesRepository;
  private readonly readingHistory: ReadingHistoryViewModel;
  private initialization: Promise<void> | undefined = undefined;
  private operationTail: Promise<void> = Promise.resolve();
  private readonly listeners: StorySeriesViewModelListener[] = [];
  private historyUnsubscribe: (() => void) | undefined = undefined;

  constructor(
    repository: StorySeriesRepository,
    readingHistory: ReadingHistoryViewModel
  ) {
    this.repository = repository;
    this.readingHistory = readingHistory;
    this.historyUnsubscribe = this.readingHistory.subscribe((): void => {
      this.stateRevision += 1;
      this.notifyListeners();
    });
  }

  subscribe(listener: StorySeriesViewModelListener): () => void {
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
    if (this.initialized) {
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
        await this.readingHistory.initialize();
        const rows = await this.repository.listEnrollments();
        this.replaceEnrollments(rows);
        this.initialized = true;
      } catch (error) {
        this.error = error instanceof Error ? error.message : '系列进度加载失败';
        this.notifyListeners();
        throw new Error(this.error);
      } finally {
        this.loading = false;
        this.notifyListeners();
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
    if (!this.initialized) {
      await this.initialize();
      return;
    }
    await this.enqueue(async (): Promise<void> => {
      this.loading = true;
      this.notifyListeners();
      try {
        await this.readingHistory.initialize();
        const rows = await this.repository.listEnrollments();
        this.replaceEnrollments(rows);
        this.error = '';
      } catch (error) {
        this.error = error instanceof Error ? error.message : '系列进度刷新失败';
        throw new Error(this.error);
      } finally {
        this.loading = false;
        this.notifyListeners();
      }
    });
  }

  isEntryCompleted(entryId: string): boolean {
    const rev = this.stateRevision;
    if (rev < 0) {
      return false;
    }
    return this.readingHistory.isCompleted(entryId);
  }

  listProgressSnapshots(): StorySeriesProgressSnapshot[] {
    const rev = this.stateRevision;
    if (rev < 0) {
      return [];
    }
    const seriesList = listBuiltInStorySeries();
    const result: StorySeriesProgressSnapshot[] = [];
    for (let index = 0; index < seriesList.length; index++) {
      const snapshot = this.buildSnapshot(seriesList[index]);
      result.push(snapshot);
    }
    return result;
  }

  listEnrolledSnapshots(): StorySeriesProgressSnapshot[] {
    const all = this.listProgressSnapshots();
    const enrolled: StorySeriesProgressSnapshot[] = [];
    for (let index = 0; index < all.length; index++) {
      if (all[index].enrolled) {
        enrolled.push(all[index]);
      }
    }
    enrolled.sort((left: StorySeriesProgressSnapshot, right: StorySeriesProgressSnapshot): number => {
      if (left.updatedAt !== right.updatedAt) {
        return right.updatedAt - left.updatedAt;
      }
      return left.series.id.localeCompare(right.series.id);
    });
    return enrolled;
  }

  snapshotFor(seriesId: string): StorySeriesProgressSnapshot | undefined {
    const rev = this.stateRevision;
    if (rev < 0) {
      return undefined;
    }
    const series = findStorySeriesById(seriesId);
    return series !== undefined ? this.buildSnapshot(series) : undefined;
  }

  /**
   * Resolve story series context for an article route.
   * Hubs always surface series controls; member entries surface controls only
   * when launched via series flow or when already enrolled. Non-member detours
   * return `undefined` without disturbing stored series progress.
   */
  resolveArticleContext(
    articleId: string,
    preferredSeriesId: string = ''
  ): StorySeriesArticleContext | undefined {
    const rev = this.stateRevision;
    if (rev < 0) {
      return undefined;
    }
    const normalizedArticleId = normalizeSeriesPageId(articleId);
    if (normalizedArticleId.length === 0) {
      return undefined;
    }
    const hubSeries = findStorySeriesByHubId(normalizedArticleId);
    if (hubSeries !== undefined) {
      return buildStorySeriesArticleContext(
        hubSeries,
        normalizedArticleId,
        this.findEnrollment(hubSeries.id),
        (id: string): boolean => this.readingHistory.isCompleted(id)
      );
    }

    const normalizedPreferred = normalizeSeriesPageId(preferredSeriesId);
    if (normalizedPreferred.length > 0) {
      const preferredSeries = findStorySeriesById(normalizedPreferred);
      if (preferredSeries !== undefined && containsSeriesEntry(preferredSeries, normalizedArticleId)) {
        return buildStorySeriesArticleContext(
          preferredSeries,
          normalizedArticleId,
          this.findEnrollment(preferredSeries.id),
          (id: string): boolean => this.readingHistory.isCompleted(id)
        );
      }
    }

    const candidates = findStorySeriesByMemberId(normalizedArticleId);
    let bestEnrollment: StorySeriesEnrollment | undefined = undefined;
    let bestSeries: StorySeriesDefinition | undefined = undefined;
    for (let index = 0; index < candidates.length; index++) {
      const candidate = candidates[index];
      const enrollment = this.findEnrollment(candidate.id);
      if (enrollment !== undefined && enrollment.enrolled) {
        if (bestEnrollment === undefined || enrollment.updatedAt > bestEnrollment.updatedAt) {
          bestEnrollment = enrollment;
          bestSeries = candidate;
        }
      }
    }
    if (bestSeries !== undefined) {
      return buildStorySeriesArticleContext(
        bestSeries,
        normalizedArticleId,
        bestEnrollment,
        (id: string): boolean => this.readingHistory.isCompleted(id)
      );
    }
    return undefined;
  }

  async startSeries(seriesId: string): Promise<StorySeriesEntry | undefined> {
    await this.initialize();
    const series = findStorySeriesById(seriesId);
    if (series === undefined) {
      return undefined;
    }
    let resolvedTarget: StorySeriesEntry | undefined = undefined;
    await this.enqueue(async (): Promise<void> => {
      const existing = this.findEnrollment(series.id);
      const nextTarget = resolveSeriesResumeEntry(
        series,
        existing,
        (id: string): boolean => this.readingHistory.isCompleted(id)
      );
      resolvedTarget = nextTarget;
      const now = Date.now();
      const targetId = nextTarget !== undefined ? nextTarget.id :
        (existing !== undefined ? existing.currentEntryId : '');
      const saved = await this.repository.saveEnrollment(new StorySeriesEnrollment(
        series.id,
        true,
        targetId,
        existing !== undefined && existing.enrolledAt > 0 ? existing.enrolledAt : now,
        now
      ));
      this.publishEnrollment(saved);
    });
    return resolvedTarget;
  }

  async recordMemberOpened(
    seriesId: string,
    entryId: string,
    enrollIfNeeded: boolean = false
  ): Promise<void> {
    await this.initialize();
    const series = findStorySeriesById(seriesId);
    if (series === undefined) {
      return;
    }
    const normalizedEntryId = normalizeSeriesPageId(entryId);
    if (!containsSeriesEntry(series, normalizedEntryId)) {
      // Detours outside the series never overwrite the active series cursor.
      return;
    }
    await this.enqueue(async (): Promise<void> => {
      const existing = this.findEnrollment(series.id);
      const currentlyEnrolled = existing !== undefined && existing.enrolled;
      if (!currentlyEnrolled && !enrollIfNeeded) {
        return;
      }
      if (currentlyEnrolled && existing!.currentEntryId === normalizedEntryId) {
        return;
      }
      const now = Date.now();
      const saved = await this.repository.saveEnrollment(new StorySeriesEnrollment(
        series.id,
        true,
        normalizedEntryId,
        existing !== undefined && existing.enrolledAt > 0 ? existing.enrolledAt : now,
        now
      ));
      this.publishEnrollment(saved);
    });
  }

  dispose(): void {
    this.historyUnsubscribe?.();
    this.historyUnsubscribe = undefined;
  }

  private buildSnapshot(series: StorySeriesDefinition): StorySeriesProgressSnapshot {
    const enrollment = this.findEnrollment(series.id);
    const counts = countSeriesProgress(
      series,
      (id: string): boolean => this.readingHistory.isCompleted(id)
    );
    const resumeEntry = resolveSeriesResumeEntry(
      series,
      enrollment,
      (id: string): boolean => this.readingHistory.isCompleted(id)
    );
    return new StorySeriesProgressSnapshot(
      series,
      enrollment !== undefined && enrollment.enrolled,
      enrollment !== undefined ? enrollment.currentEntryId : '',
      counts[1],
      counts[0],
      counts[3],
      counts[2],
      resumeEntry,
      enrollment !== undefined ? enrollment.updatedAt : 0
    );
  }

  private findEnrollment(seriesId: string): StorySeriesEnrollment | undefined {
    const normalized = normalizeSeriesPageId(seriesId);
    for (let index = 0; index < this.enrollments.length; index++) {
      if (this.enrollments[index].seriesId === normalized) {
        return this.enrollments[index];
      }
    }
    return undefined;
  }

  private replaceEnrollments(rows: StorySeriesEnrollment[]): void {
    const next = rows.slice();
    next.sort((left: StorySeriesEnrollment, right: StorySeriesEnrollment): number => {
      if (left.updatedAt !== right.updatedAt) {
        return right.updatedAt - left.updatedAt;
      }
      return left.seriesId.localeCompare(right.seriesId);
    });
    this.enrollments = next;
    let count = 0;
    for (let index = 0; index < next.length; index++) {
      if (next[index].enrolled) {
        count++;
      }
    }
    this.enrolledCount = count;
    this.stateRevision += 1;
  }

  private publishEnrollment(saved: StorySeriesEnrollment): void {
    const next: StorySeriesEnrollment[] = [saved];
    for (let index = 0; index < this.enrollments.length; index++) {
      if (this.enrollments[index].seriesId !== saved.seriesId) {
        next.push(this.enrollments[index]);
      }
    }
    this.replaceEnrollments(next);
    this.notifyListeners();
  }

  private enqueue(operation: () => Promise<void>): Promise<void> {
    const next = this.operationTail.then(operation, operation);
    this.operationTail = next.catch((): void => {
    });
    return next;
  }

  private notifyListeners(): void {
    const listeners = this.listeners.slice();
    for (let index = 0; index < listeners.length; index++) {
      try {
        listeners[index]();
      } catch (_error) {
      }
    }
  }
}
