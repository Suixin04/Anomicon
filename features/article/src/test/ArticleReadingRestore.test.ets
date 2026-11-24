import { describe, expect, it } from '@ohos/hypium';
import { createLibraryContentRef, LibraryContentKind, LibraryContentRef } from 'library';
import { ArticleContentUseCase } from '../main/ets/application/ArticleContentUseCase';
import {
  ArticleContentGateway,
  ArticleHistoryPort,
  ArticleHistorySnapshot,
  ArticleLoadResult,
  PendingExtraction
} from '../main/ets/domain/ArticleContracts';
import { ScpArticleDocument } from '../main/ets/domain/ScpDocument';
import { ArticleViewModel } from '../main/ets/presentation/viewmodel/ArticleViewModel';
import { createRendererDocument } from './ArticleTestFixtures';

class ImmediateDocumentGateway implements ArticleContentGateway {
  load(
    _content: LibraryContentRef,
    _requestId: number,
    _forceNetwork: boolean = false
  ): Promise<ArticleLoadResult> {
    return Promise.resolve(new ArticleLoadResult(createRendererDocument()));
  }

  completeExtraction(
    _content: LibraryContentRef,
    _pending: PendingExtraction,
    _payload: string
  ): Promise<ScpArticleDocument> {
    return Promise.resolve(createRendererDocument());
  }
}

class TestHistorySnapshot implements ArticleHistorySnapshot {
  readonly scrollOffset: number;
  readonly completed: boolean;

  constructor(scrollOffset: number, completed: boolean = false) {
    this.scrollOffset = scrollOffset;
    this.completed = completed;
  }
}

class DeferredArticleHistory implements ArticleHistoryPort {
  findCalls: number = 0;
  readonly progressOffsets: number[] = [];
  readonly completedStates: boolean[] = [];
  private findResolver:
    ((snapshot: ArticleHistorySnapshot | undefined) => void) | undefined = undefined;

  recordOpened(_content: LibraryContentRef): Promise<void> {
    return Promise.resolve();
  }

  find(_contentKey: string): Promise<ArticleHistorySnapshot | undefined> {
    this.findCalls += 1;
    return new Promise<ArticleHistorySnapshot | undefined>(
      (resolve: (snapshot: ArticleHistorySnapshot | undefined) => void): void => {
        this.findResolver = resolve;
      }
    );
  }

  updateProgress(_content: LibraryContentRef, offset: number): Promise<void> {
    this.progressOffsets.push(offset);
    return Promise.resolve();
  }

  updateMetadata(_content: LibraryContentRef): Promise<void> {
    return Promise.resolve();
  }

  setCompleted(_content: LibraryContentRef, completed: boolean): Promise<void> {
    this.completedStates.push(completed);
    return Promise.resolve();
  }

  resolveFind(offset: number, completed: boolean = false): void {
    const resolve = this.findResolver;
    if (resolve !== undefined) {
      this.findResolver = undefined;
      resolve(new TestHistorySnapshot(offset, completed));
    }
  }
}

async function drainMicrotasks(rounds: number = 20): Promise<void> {
  for (let index = 0; index < rounds; index++) {
    await Promise.resolve();
  }
}

function createRestoreViewModel(history: ArticleHistoryPort): ArticleViewModel {
  return new ArticleViewModel(
    new ArticleContentUseCase(new ImmediateDocumentGateway()),
    undefined,
    undefined,
    undefined,
    history
  );
}

function openArticle(viewModel: ArticleViewModel): void {
  viewModel.setRouteContent(createLibraryContentRef(
    LibraryContentKind.SCP,
    'scp-173',
    'SCP-173'
  ));
  viewModel.activate();
}

export default function articleReadingRestoreTest(): void {
  describe('ArticleReadingRestore', () => {
    it('does not persist the provisional zero while restore is pending', 0, async () => {
      const history = new DeferredArticleHistory();
      const viewModel = createRestoreViewModel(history);
      openArticle(viewModel);
      await drainMicrotasks();

      expect(history.findCalls).assertEqual(1);
      expect(viewModel.readingRestoreReady).assertFalse();
      await viewModel.updateProgress(0);
      expect(history.progressOffsets.length).assertEqual(0);

      history.resolveFind(480);
      await drainMicrotasks();
      expect(viewModel.readingRestoreReady).assertTrue();
      expect(viewModel.restoredScrollOffset).assertEqual(480);
      viewModel.dispose();
    });

    it('allows an authoritative zero after the lookup resolves', 0, async () => {
      const history = new DeferredArticleHistory();
      const viewModel = createRestoreViewModel(history);
      openArticle(viewModel);
      await drainMicrotasks();

      history.resolveFind(0);
      await drainMicrotasks();
      expect(viewModel.readingRestoreReady).assertTrue();
      expect(viewModel.restoredScrollOffset).assertEqual(0);

      await viewModel.updateProgress(0);
      expect(history.progressOffsets.length).assertEqual(1);
      expect(history.progressOffsets[0]).assertEqual(0);
      viewModel.dispose();
    });

    it('lets an explicit reader scroll save zero before a late restore', 0, async () => {
      const history = new DeferredArticleHistory();
      const viewModel = createRestoreViewModel(history);
      openArticle(viewModel);
      await drainMicrotasks();

      viewModel.setContinuousInteraction(true, 0);
      await viewModel.updateProgress(0);
      expect(history.progressOffsets.length).assertEqual(1);
      expect(history.progressOffsets[0]).assertEqual(0);

      history.resolveFind(640);
      await drainMicrotasks();
      expect(viewModel.restoredScrollOffset).assertEqual(640);
      viewModel.dispose();
    });

    it('preserves readingPercent updated while inactive without notifying listeners', 0, async () => {
      const history = new DeferredArticleHistory();
      const viewModel = createRestoreViewModel(history);
      openArticle(viewModel);
      await drainMicrotasks();

      viewModel.setReadingPercent(11);
      expect(viewModel.readingPercent).assertEqual(11);

      viewModel.deactivate();
      let notifications: number = 0;
      const unsubscribe = viewModel.subscribe(() => {
        notifications += 1;
      });
      viewModel.setReadingPercent(51);

      expect(notifications).assertEqual(0);
      expect(viewModel.readingPercent).assertEqual(51);

      viewModel.activate();
      expect(viewModel.readingPercent).assertEqual(51);

      unsubscribe();
      viewModel.dispose();
    });

    it('locks progress persistence when completed and resumes saving when unmarked', 0, async () => {
      const history = new DeferredArticleHistory();
      const viewModel = createRestoreViewModel(history);
      openArticle(viewModel);
      await drainMicrotasks();

      history.resolveFind(480, true);
      await drainMicrotasks();
      expect(viewModel.completed).assertTrue();
      expect(viewModel.restoredScrollOffset).assertEqual(0);

      await viewModel.updateProgress(320);
      await viewModel.updateProgress(0);
      expect(history.progressOffsets.length).assertEqual(0);

      await viewModel.setCompleted(false);
      expect(viewModel.completed).assertFalse();
      expect(history.completedStates.length).assertEqual(1);
      expect(history.completedStates[0]).assertFalse();

      await viewModel.updateProgress(320);
      expect(history.progressOffsets.length).assertEqual(1);
      expect(history.progressOffsets[0]).assertEqual(320);
      viewModel.dispose();
    });
  });
}
