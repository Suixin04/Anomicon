import {
  LibraryContentRef,
  LibraryFavorite,
  ReadingHistoryEntry,
  ResearchActivitySnapshot,
  ResearchProgress
} from 'library';
import {
  FavoritesViewModel,
  ReadingHistoryViewModel,
  ResearchProfileViewModel
} from 'library';
import {
  TerminalFavoritesPort,
  TerminalReadingHistoryPort,
  TerminalResearchProfilePort,
  TerminalViewModelListener
} from 'terminal';

/** Product composition bridge from Library shared favorites to Terminal's narrow port. */
export class TerminalFavoritesAdapter implements TerminalFavoritesPort {
  private readonly state: FavoritesViewModel;

  constructor(state: FavoritesViewModel) {
    this.state = state;
  }

  get items(): LibraryFavorite[] {
    return this.state.items;
  }

  get loading(): boolean {
    return this.state.loading;
  }

  get error(): string {
    return this.state.error;
  }

  get initialized(): boolean {
    return this.state.initialized;
  }

  subscribe(listener: TerminalViewModelListener): () => void {
    return this.state.subscribe((): void => listener());
  }

  initialize(): Promise<void> {
    return this.state.initialize();
  }

  reload(): Promise<void> {
    return this.state.reload();
  }
}

/** Product composition bridge from Library history to Terminal's projection and title command. */
export class TerminalReadingHistoryAdapter implements TerminalReadingHistoryPort {
  private readonly state: ReadingHistoryViewModel;

  constructor(state: ReadingHistoryViewModel) {
    this.state = state;
  }

  get items(): ReadingHistoryEntry[] {
    return this.state.items;
  }

  get resumableItems(): ReadingHistoryEntry[] {
    return this.state.resumableItems;
  }

  get loading(): boolean {
    return this.state.loading;
  }

  get error(): string {
    return this.state.error;
  }

  get initialized(): boolean {
    return this.state.initialized;
  }

  subscribe(listener: TerminalViewModelListener): () => void {
    return this.state.subscribe((): void => listener());
  }

  initialize(): Promise<void> {
    return this.state.initialize();
  }

  reload(): Promise<void> {
    return this.state.reload();
  }

  updateMetadata(content: LibraryContentRef): Promise<void> {
    return this.state.updateMetadata(content);
  }
}

/** Product composition bridge exposing only the read-only research profile used by Terminal. */
export class TerminalResearchProfileAdapter implements TerminalResearchProfilePort {
  private readonly state: ResearchProfileViewModel;

  constructor(state: ResearchProfileViewModel) {
    this.state = state;
  }

  get profile(): ResearchProgress {
    return this.state.profile;
  }

  get loading(): boolean {
    return this.state.loading;
  }

  get error(): string {
    return this.state.error;
  }

  get initialized(): boolean {
    return this.state.initialized;
  }

  subscribe(listener: TerminalViewModelListener): () => void {
    return this.state.subscribe((): void => listener());
  }

  initialize(): Promise<void> {
    return this.state.initialize();
  }

  reload(): Promise<ResearchActivitySnapshot> {
    return this.state.reload();
  }
}
