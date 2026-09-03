import {
  ArticleFavoritePort,
  ArticleHistoryPort,
  ArticleHistorySnapshot
} from 'article';
import { LibraryContentRef } from 'library';
import { FavoritesViewModel } from 'library';
import { ReadingHistoryViewModel } from 'library';
import { ReadingActivityCoord } from 'library';
import { ReadingSessionPort } from 'article';
import { IdGeneratorPort } from 'anomiconbasic';

/**
 * Composition-root bridge for the shared favorites state.  Keeping an
 * explicit implementation (rather than passing FavoritesViewModel directly)
 * preserves ArkTS's nominal typing and prevents the Article feature from
 * depending on a library presentation class.
 */
export class ArticleFavoriteAdapter implements ArticleFavoritePort {
  private readonly state: FavoritesViewModel;

  constructor(state: FavoritesViewModel) {
    this.state = state;
  }

  get initialized(): boolean {
    return this.state.initialized;
  }

  get loading(): boolean {
    return this.state.loading;
  }

  isFavorite(contentKey: string): boolean {
    return this.state.isFavorite(contentKey);
  }

  initialize(): Promise<void> {
    return this.state.initialize();
  }

  toggle(content: LibraryContentRef): Promise<boolean> {
    return this.state.toggle(content);
  }

  subscribe(listener: () => void): () => void {
    return this.state.subscribe(listener);
  }
}

/**
 * Composition-root adapter for the shared Library reading-history state.
 *
 * Article receives only the four operations it needs for a reader screen;
 * list/reload and the Library ViewModel's observable state stay private
 * to the product/library boundary.  The adapter deliberately returns a plain
 * serializable snapshot instead of exposing ReadingHistoryEntry.
 */
export class ArticleHistoryAdapter implements ArticleHistoryPort {
  private readonly state: ReadingHistoryViewModel;

  constructor(state: ReadingHistoryViewModel) {
    this.state = state;
  }

  recordOpened(content: LibraryContentRef): Promise<void> {
    return this.state.recordOpened(content);
  }

  async find(contentKey: string): Promise<ArticleHistorySnapshot | undefined> {
    const entry = await this.state.find(contentKey);
    if (entry === undefined) {
      return undefined;
    }
    return {
      scrollOffset: this.normalizeOffset(entry.scrollOffset),
      completed: entry.completed
    };
  }

  updateProgress(content: LibraryContentRef, offset: number): Promise<void> {
    return this.state.updateProgress(content, this.normalizeOffset(offset));
  }

  updateMetadata(content: LibraryContentRef): Promise<void> {
    return this.state.updateMetadata(content);
  }

  setCompleted(content: LibraryContentRef, completed: boolean): Promise<void> {
    return this.state.setCompleted(content, completed);
  }

  private normalizeOffset(offset: number): number {
    if (!Number.isFinite(offset) || offset <= 0) {
      return 0;
    }
    return Math.floor(offset);
  }
}

/**
 * Composition-bound adapter for the article reading-session port.
 *
 * The coordinator still owns the monotonic clock, XP policy and persistence;
 * the Article feature only sends content-level lifecycle events.  A stable
 * owner id is generated per screen VM so an old route cannot release a newer
 * route that happens to point at the same page slug.
 */
export class ReadingSessionAdapter implements ReadingSessionPort {
  private readonly coordinator: ReadingActivityCoord;
  private readonly ownerId: string;

  constructor(coordinator: ReadingActivityCoord, idGenerator: IdGeneratorPort) {
    this.coordinator = coordinator;
    this.ownerId = idGenerator.generate();
  }

  attach(content: LibraryContentRef, offset: number): void {
    this.coordinator.attachPage(this.ownerId, content, false, offset);
  }

  setContentReady(content: LibraryContentRef, ready: boolean, offset: number): void {
    this.coordinator.setContentReady(this.ownerId, content, ready, offset);
  }

  setShown(content: LibraryContentRef, shown: boolean, ready: boolean, offset: number): void {
    this.coordinator.setPageShown(this.ownerId, content, shown, ready, offset);
  }

  setActive(content: LibraryContentRef, active: boolean, ready: boolean, offset: number): void {
    this.coordinator.setPageActive(this.ownerId, content, active, ready, offset);
  }

  noteInteraction(content: LibraryContentRef, offset: number): void {
    this.coordinator.noteInteraction(this.ownerId, content, offset);
  }

  setContinuousInteraction(content: LibraryContentRef, active: boolean, offset: number): void {
    this.coordinator.setContinuousInteraction(this.ownerId, content, active, offset);
  }

  checkpoint(content: LibraryContentRef, offset: number): void {
    this.coordinator.checkpoint(this.ownerId, content, offset);
  }

  release(contentKey: string, offset: number): void {
    this.coordinator.releasePage(this.ownerId, contentKey, offset);
  }
}
