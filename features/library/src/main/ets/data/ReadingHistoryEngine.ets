import {
  LibraryContentRef,
  preferLibraryContentMetadata
} from '../domain/LibraryContentRef';
import {
  READING_HISTORY_LIMIT,
  ReadingHistoryEntry,
  ReadingStateEntry,
  hasPermanentReadingState,
  normalizeReadingScrollOffset
} from '../domain/ReadingHistoryEntry';
import { ReadingHistoryRepository } from '../domain/LibraryRepositories';

/** Atomic persistence unit spanning recent history and permanent reading state. */
export class ReadingHistoryMutation {
  readonly historyEntry: ReadingHistoryEntry | undefined;
  readonly stateEntry: ReadingStateEntry | undefined;
  readonly deleteStateKey: string | undefined;

  constructor(
    historyEntry: ReadingHistoryEntry | undefined,
    stateEntry: ReadingStateEntry | undefined,
    deleteStateKey: string | undefined = undefined
  ) {
    this.historyEntry = historyEntry;
    this.stateEntry = stateEntry;
    this.deleteStateKey = deleteStateKey;
  }
}

/** Narrow storage port so business state transitions can be tested without RDB. */
export interface ReadingHistoryStorageAdapter {
  listHistory(limit: number): Promise<ReadingHistoryEntry[]>;
  findHistory(contentKey: string): Promise<ReadingHistoryEntry | undefined>;
  listStates(): Promise<ReadingStateEntry[]>;
  findState(contentKey: string): Promise<ReadingStateEntry | undefined>;
  commitMutation(mutation: ReadingHistoryMutation): Promise<void>;
  pruneHistory(limit: number): Promise<void>;
}

/**
 * Coordinates the bounded recency log and the unbounded permanent reading state.
 */
export class ReadingHistoryStoreEngine implements ReadingHistoryRepository {
  private readonly storage: ReadingHistoryStorageAdapter;
  private readonly historyLimit: number;
  private readonly nowProvider: () => number;

  constructor(
    storage: ReadingHistoryStorageAdapter,
    historyLimit: number = READING_HISTORY_LIMIT,
    nowProvider: () => number = (): number => Date.now()
  ) {
    this.storage = storage;
    this.historyLimit = Number.isFinite(historyLimit) && historyLimit >= 1
      ? Math.floor(historyLimit) : READING_HISTORY_LIMIT;
    this.nowProvider = nowProvider;
  }

  list(): Promise<ReadingHistoryEntry[]> {
    return this.storage.listHistory(this.historyLimit);
  }

  listStates(): Promise<ReadingStateEntry[]> {
    return this.storage.listStates();
  }

  async find(contentKey: string): Promise<ReadingHistoryEntry | undefined> {
    const existingHistory = await this.storage.findHistory(contentKey);
    const existingState = await this.storage.findState(contentKey);
    if (existingHistory !== undefined) {
      const resolvedContent = existingState !== undefined ?
        preferLibraryContentMetadata(existingHistory.content, existingState.content) :
        existingHistory.content;
      const scrollOffset = existingState !== undefined ?
        existingState.scrollOffset : existingHistory.scrollOffset;
      const completed = existingState !== undefined ?
        existingState.completed : existingHistory.completed;
      return new ReadingHistoryEntry(
        resolvedContent,
        existingHistory.openedAt,
        existingHistory.lastReadAt,
        scrollOffset,
        completed
      );
    }
    if (existingState !== undefined) {
      return new ReadingHistoryEntry(
        existingState.content,
        existingState.updatedAt,
        existingState.updatedAt,
        existingState.scrollOffset,
        existingState.completed
      );
    }
    return undefined;
  }

  async recordOpened(content: LibraryContentRef): Promise<ReadingHistoryEntry> {
    const existingHistory = await this.storage.findHistory(content.key);
    const existingState = await this.storage.findState(content.key);
    const now = this.nowProvider();
    const openedAt = existingHistory === undefined ? now : existingHistory.openedAt;
    const scrollOffset = existingState !== undefined ?
      existingState.scrollOffset : (existingHistory?.scrollOffset ?? 0);
    const completed = existingState !== undefined ?
      existingState.completed : (existingHistory?.completed ?? false);
    const completedAt = existingState !== undefined ?
      existingState.completedAt : (completed ? (existingHistory?.lastReadAt ?? now) : 0);
    const resolvedContent = this.resolveMetadata(content, existingHistory, existingState);
    const entry = new ReadingHistoryEntry(
      resolvedContent,
      openedAt,
      now,
      scrollOffset,
      completed
    );
    const nextState = hasPermanentReadingState(scrollOffset, completed) ?
      new ReadingStateEntry(resolvedContent, scrollOffset, completed, completedAt, now) :
      undefined;
    await this.storage.commitMutation(new ReadingHistoryMutation(entry, nextState, undefined));
    if (existingHistory === undefined) {
      await this.storage.pruneHistory(this.historyLimit);
    }
    return entry;
  }

  async updateProgress(content: LibraryContentRef, offset: number): Promise<ReadingHistoryEntry> {
    const existingHistory = await this.storage.findHistory(content.key);
    const existingState = await this.storage.findState(content.key);
    const now = this.nowProvider();
    const openedAt = existingHistory === undefined ? now : existingHistory.openedAt;
    const normalizedOffset = normalizeReadingScrollOffset(offset);
    const completed = existingState !== undefined ?
      existingState.completed : (existingHistory?.completed ?? false);
    const completedAt = existingState !== undefined ?
      existingState.completedAt : (completed ? (existingHistory?.lastReadAt ?? now) : 0);
    const resolvedContent = this.resolveMetadata(content, existingHistory, existingState);
    const entry = new ReadingHistoryEntry(
      resolvedContent,
      openedAt,
      now,
      normalizedOffset,
      completed
    );
    const keepState = hasPermanentReadingState(normalizedOffset, completed);
    const nextState = keepState ?
      new ReadingStateEntry(resolvedContent, normalizedOffset, completed, completedAt, now) :
      undefined;
    const deleteStateKey = keepState ? undefined : content.key;
    await this.storage.commitMutation(new ReadingHistoryMutation(entry, nextState, deleteStateKey));
    if (existingHistory === undefined) {
      await this.storage.pruneHistory(this.historyLimit);
    }
    return entry;
  }

  async setCompleted(content: LibraryContentRef, completed: boolean): Promise<ReadingHistoryEntry> {
    const existingHistory = await this.storage.findHistory(content.key);
    const existingState = await this.storage.findState(content.key);
    const now = this.nowProvider();
    const openedAt = existingHistory === undefined ? now : existingHistory.openedAt;
    const scrollOffset = existingState !== undefined ?
      existingState.scrollOffset : (existingHistory?.scrollOffset ?? 0);
    const nextCompleted = completed === true;
    const wasCompleted = existingState !== undefined ?
      existingState.completed : (existingHistory?.completed ?? false);
    const completedAt = nextCompleted ?
      (wasCompleted && existingState !== undefined && existingState.completedAt > 0 ?
        existingState.completedAt : now) :
      0;
    const resolvedContent = this.resolveMetadata(content, existingHistory, existingState);
    const entry = new ReadingHistoryEntry(
      resolvedContent,
      openedAt,
      now,
      scrollOffset,
      nextCompleted
    );
    const keepState = hasPermanentReadingState(scrollOffset, nextCompleted);
    const nextState = keepState ?
      new ReadingStateEntry(resolvedContent, scrollOffset, nextCompleted, completedAt, now) :
      undefined;
    const deleteStateKey = keepState ? undefined : content.key;
    await this.storage.commitMutation(new ReadingHistoryMutation(entry, nextState, deleteStateKey));
    if (existingHistory === undefined) {
      await this.storage.pruneHistory(this.historyLimit);
    }
    return entry;
  }

  async updateMetadata(content: LibraryContentRef): Promise<ReadingHistoryEntry | undefined> {
    const existingHistory = await this.storage.findHistory(content.key);
    const existingState = await this.storage.findState(content.key);
    if (existingHistory === undefined && existingState === undefined) {
      return undefined;
    }

    let nextHistory: ReadingHistoryEntry | undefined = undefined;
    if (existingHistory !== undefined) {
      const resolvedHistoryContent = this.resolveMetadata(content, existingHistory, existingState);
      if (resolvedHistoryContent.title !== existingHistory.content.title ||
        resolvedHistoryContent.kind !== existingHistory.content.kind) {
        const scrollOffset = existingState !== undefined ?
          existingState.scrollOffset : existingHistory.scrollOffset;
        const completed = existingState !== undefined ?
          existingState.completed : existingHistory.completed;
        nextHistory = new ReadingHistoryEntry(
          resolvedHistoryContent,
          existingHistory.openedAt,
          existingHistory.lastReadAt,
          scrollOffset,
          completed
        );
      }
    }

    let nextState: ReadingStateEntry | undefined = undefined;
    if (existingState !== undefined) {
      const resolvedStateContent = this.resolveMetadata(content, existingHistory, existingState);
      if (resolvedStateContent.title !== existingState.content.title ||
        resolvedStateContent.kind !== existingState.content.kind) {
        nextState = new ReadingStateEntry(
          resolvedStateContent,
          existingState.scrollOffset,
          existingState.completed,
          existingState.completedAt,
          existingState.updatedAt
        );
      }
    }

    if (nextHistory !== undefined || nextState !== undefined) {
      await this.storage.commitMutation(new ReadingHistoryMutation(nextHistory, nextState, undefined));
    }

    if (nextHistory !== undefined) {
      return nextHistory;
    }
    if (existingHistory !== undefined) {
      return existingHistory;
    }
    const resolvedState = nextState ?? existingState!;
    return new ReadingHistoryEntry(
      resolvedState.content,
      resolvedState.updatedAt,
      resolvedState.updatedAt,
      resolvedState.scrollOffset,
      resolvedState.completed
    );
  }

  private resolveMetadata(
    incoming: LibraryContentRef,
    existingHistory: ReadingHistoryEntry | undefined,
    existingState: ReadingStateEntry | undefined
  ): LibraryContentRef {
    const afterHistory = preferLibraryContentMetadata(incoming, existingHistory?.content);
    return preferLibraryContentMetadata(afterHistory, existingState?.content);
  }
}
