import { describe, expect, it } from '@ohos/hypium';
import { createLibraryContentRef, LibraryContentKind, LibraryContentRef } from 'library';
import { ArticleContentUseCase } from '../main/ets/application/ArticleContentUseCase';
import { ContentGateway } from '../main/ets/data/ContentGateway';
import {
  ArticleContentSource,
  ArticleDocumentCachePort,
  ArticleDocumentCacheRecord,
  ArticleDocumentParserPort,
  ArticleHtmlPort,
  ArticleHtmlSnapshot,
  ArticleHtmlSource
} from '../main/ets/domain/ArticleContracts';
import {
  ArticleOfflineDocumentRecord,
  ArticleOfflineSaveAction,
  ArticleOfflineSaveProgress,
  ArticleOfflineSnapshot,
  ArticleOfflineStatus,
  ArticleOfflineStoragePort,
  ArticleOfflineStoreListener,
  ArticleOfflineSummary,
  collectArticleImageUrls,
  evaluateOfflineReadiness,
  normalizeOfflineImageUrl,
  requiresNetworkForInteractiveDocument
} from '../main/ets/domain/ArticleOfflineContracts';
import {
  ScpArticleDocument,
  ScpBlockType,
  ScpContentBlock,
  ScpFootnote
} from '../main/ets/domain/ScpDocument';
import { ArticleViewModel } from '../main/ets/presentation/viewmodel/ArticleViewModel';

class OfflineMemoryHtmlPort implements ArticleHtmlPort {
  fail: boolean = false;
  html: string = '<html></html>';
  source: ArticleHtmlSource = ArticleHtmlSource.NETWORK;
  requests: boolean[] = [];

  load(_sourceUrl: string, forceNetwork: boolean = false): Promise<ArticleHtmlSnapshot> {
    this.requests.push(forceNetwork);
    if (this.fail) {
      return Promise.reject(new Error('network offline'));
    }
    return Promise.resolve(new ArticleHtmlSnapshot(this.html, this.source, 100));
  }
}

class EmptyDocCachePort implements ArticleDocumentCachePort {
  get(_itemId: string): Promise<ArticleDocumentCacheRecord | undefined> {
    return Promise.resolve(undefined);
  }

  put(_record: ArticleDocumentCacheRecord): Promise<void> {
    return Promise.resolve();
  }

  isFresh(_record: ArticleDocumentCacheRecord): boolean {
    return true;
  }
}

class StaticDocParserPort implements ArticleDocumentParserPort {
  private readonly document: ScpArticleDocument;

  constructor(document: ScpArticleDocument) {
    this.document = document;
  }

  parse(_payloadText: string, _sourceUrl: string, _fetchedAt: number): ScpArticleDocument {
    return this.document;
  }

  parseHtmlPayload(_html: string): Promise<string> {
    return Promise.resolve('{"ok":true}');
  }

  currentSchemaVersion(): number {
    return 1;
  }
}

class MemoryOfflineStore implements ArticleOfflineStoragePort {
  records: Map<string, ArticleOfflineDocumentRecord> = new Map();
  saveCount: number = 0;
  requireAllImages: boolean = false;

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  inspect(content: LibraryContentRef): Promise<ArticleOfflineSnapshot | undefined> {
    return Promise.resolve(this.records.get(content.key)?.snapshot);
  }

  loadDocument(content: LibraryContentRef): Promise<ArticleOfflineDocumentRecord | undefined> {
    return Promise.resolve(this.records.get(content.key));
  }

  save(
    content: LibraryContentRef,
    document: ScpArticleDocument,
    rawPayloadJson: string,
    onProgress?: (progress: ArticleOfflineSaveProgress) => void,
    requireAllImages: boolean = false
  ): Promise<ArticleOfflineSnapshot> {
    this.saveCount++;
    this.requireAllImages = requireAllImages;
    const urls = collectArticleImageUrls(document);
    onProgress?.({ completedImages: 0, totalImages: urls.length });
    const localUris: Map<string, string> = new Map();
    for (let index = 0; index < urls.length; index++) {
      localUris.set(urls[index], `file:///data/storage/el2/base/files/offline_articles/v1/test/images/${index}.png`);
    }
    onProgress?.({ completedImages: urls.length, totalImages: urls.length });
    const interactive = requiresNetworkForInteractiveDocument(document);
    const readiness = evaluateOfflineReadiness(urls.length, urls.length, interactive);
    const snapshot = new ArticleOfflineSnapshot(
      content.key,
      content.kind,
      content.id,
      document.title,
      document.sourceUrl,
      999,
      4096,
      urls.length,
      urls.length,
      readiness.missingImages,
      interactive,
      readiness.status,
      readiness.badgeText,
      readiness.detailText,
      localUris
    );
    this.records.set(content.key, {
      document,
      rawPayloadJson,
      savedAt: 999,
      snapshot
    });
    return Promise.resolve(snapshot);
  }

  remove(contentKey: string): Promise<void> {
    this.records.delete(contentKey);
    return Promise.resolve();
  }

  listSummaries(): Promise<ArticleOfflineSummary[]> {
    const out: ArticleOfflineSummary[] = [];
    this.records.forEach((record: ArticleOfflineDocumentRecord): void => {
      const s = record.snapshot;
      out.push(new ArticleOfflineSummary(
        s.contentKey,
        s.contentKind,
        s.itemId,
        s.title,
        s.sourceUrl,
        s.savedAt,
        s.totalBytes,
        s.totalImages,
        s.savedImages,
        s.missingImages,
        s.requiresNetworkInteractive,
        s.status,
        s.badgeText,
        s.detailText
      ));
    });
    return Promise.resolve(out);
  }

  subscribe(_listener: ArticleOfflineStoreListener): () => void {
    return (): void => {};
  }
}

async function drainMicrotasks(rounds: number = 24): Promise<void> {
  for (let index: number = 0; index < rounds; index++) {
    await Promise.resolve();
  }
}

function makeSample2521Document(): ScpArticleDocument {
  const imageA = 'http://scp-wiki.wdfiles.com/local--files/scp-2521/a.png';
  const imageB = 'http://scp-wiki.wdfiles.com/local--files/scp-2521/b.png\r';
  const collapsibleImage = new ScpContentBlock(
    'b-col',
    ScpBlockType.COLLAPSIBLE,
    [],
    '',
    '附图',
    0,
    [new ScpContentBlock('b-col-img', ScpBlockType.IMAGE, [], imageB, '')]
  );
  const fnBlock = new ScpContentBlock(
    'fn-img',
    ScpBlockType.IMAGE,
    [],
    'https://scp-wiki.wdfiles.com/local--files/scp-2521/a.png#frag',
    ''
  );
  return new ScpArticleDocument(
    'SCP-2521',
    '●●|●●●●●|●●|●',
    'Keter',
    'https://scp-wiki-cn.wikidot.com/scp-2521',
    1000,
    [
      new ScpContentBlock('b-img-1', ScpBlockType.IMAGE, [], imageA, ''),
      collapsibleImage
    ],
    [new ScpFootnote('f-1', 1, [fnBlock])],
    '',
    [],
    '+500',
    ['keter'],
    'v1',
    [
      new ScpContentBlock('gal-1', ScpBlockType.IMAGE, [], imageA, ''),
      new ScpContentBlock('gal-2', ScpBlockType.IMAGE, [], imageB, '')
    ],
    []
  );
}

const REVISION_URL: string = 'https://scp-wiki-cn.wikidot.com/scp-2521';

function revisionDocument(revision: string): ScpArticleDocument {
  return new ScpArticleDocument('SCP-2521', revision, '', REVISION_URL, 100,
    [new ScpContentBlock('img', ScpBlockType.IMAGE, [], `${REVISION_URL}/${revision}.png`)]);
}

class RevisionParser implements ArticleDocumentParserPort {
  useWebExtractor: boolean = false;

  parse(payload: string, _sourceUrl: string, _fetchedAt: number): ScpArticleDocument {
    return revisionDocument(JSON.parse(payload) as string);
  }

  parseHtmlPayload(html: string): Promise<string> {
    if (this.useWebExtractor) {
      return Promise.reject(new Error('use web extractor'));
    }
    return Promise.resolve(JSON.stringify(html));
  }

  currentSchemaVersion(): number {
    return 1;
  }
}

class RevisionCache extends EmptyDocCachePort {
  get(itemId: string): Promise<ArticleDocumentCacheRecord | undefined> {
    const cached: ArticleDocumentCacheRecord = { itemId, json: '"v2"', schemaVersion: 1, parsedAt: 101 };
    return Promise.resolve(cached);
  }
}

class ShelfScenario {
  readonly content: LibraryContentRef = createLibraryContentRef(LibraryContentKind.SCP, 'scp-2521', 'SCP-2521');
  readonly store: MemoryOfflineStore = new MemoryOfflineStore();
  readonly html: OfflineMemoryHtmlPort = new OfflineMemoryHtmlPort();
  readonly parser: RevisionParser = new RevisionParser();
  readonly gateway: ContentGateway = new ContentGateway(this.html, new RevisionCache(), this.parser, this.store);
  readonly vm: ArticleViewModel = new ArticleViewModel(new ArticleContentUseCase(this.gateway, undefined, this.store));

  async open(offlineCopy: boolean): Promise<void> {
    this.html.html = 'v2';
    await this.store.save(this.content, revisionDocument('v1'), '"v1"');
    this.vm.setRouteContent(this.content, offlineCopy);
    this.vm.activate();
    await drainMicrotasks();
  }
}

export default function articleOfflineTest(): void {
  describe('ArticleOfflineContractsAndGateway', () => {
    it('normalizes image URLs, strips control whitespace, and rejects unsafe schemes', 0, () => {
      expect(
        normalizeOfflineImageUrl('http://scp-wiki.wdfiles.com/local--files/scp-2521/b.png\r')
      ).assertEqual('https://scp-wiki.wdfiles.com/local--files/scp-2521/b.png');
      expect(
        normalizeOfflineImageUrl('//scp-wiki.wdfiles.com/local--files/scp-2521/c.png#section')
      ).assertEqual('https://scp-wiki.wdfiles.com/local--files/scp-2521/c.png');
      expect(
        normalizeOfflineImageUrl('/local--files/scp-2521/d.png', 'https://scp-wiki-cn.wikidot.com/scp-2521')
      ).assertEqual('https://scp-wiki-cn.wikidot.com/local--files/scp-2521/d.png');
      expect(normalizeOfflineImageUrl('javascript:alert(1)')).assertEqual('');
      expect(normalizeOfflineImageUrl('data:image/png;base64,AAAA')).assertEqual('');
      expect(normalizeOfflineImageUrl('file:///etc/passwd')).assertEqual('');
    });

    it('collects deduplicated article images across blocks, collapsibles, and footnotes', 0, () => {
      const doc = makeSample2521Document();
      const urls = collectArticleImageUrls(doc);
      expect(urls.length).assertEqual(2);
      expect(urls[0]).assertEqual('https://scp-wiki.wdfiles.com/local--files/scp-2521/a.png');
      expect(urls[1]).assertEqual('https://scp-wiki.wdfiles.com/local--files/scp-2521/b.png');
      expect(requiresNetworkForInteractiveDocument(doc)).assertFalse();
    });

    it('evaluates exact reader-facing offline readiness labels and interactive detection', 0, () => {
      const readyWithImages = evaluateOfflineReadiness(15, 15, false);
      expect(readyWithImages.status).assertEqual(ArticleOfflineStatus.READY);
      expect(readyWithImages.badgeText).assertEqual('正文与图片已就绪');

      const readyNoImages = evaluateOfflineReadiness(0, 0, false);
      expect(readyNoImages.status).assertEqual(ArticleOfflineStatus.READY);
      expect(readyNoImages.badgeText).assertEqual('正文已就绪');

      const missing = evaluateOfflineReadiness(15, 12, false);
      expect(missing.status).assertEqual(ArticleOfflineStatus.MISSING_IMAGES);
      expect(missing.badgeText).assertEqual('仍缺 3 张图');
      expect(missing.missingImages).assertEqual(3);

      const interactiveOnly = evaluateOfflineReadiness(2, 2, true);
      expect(interactiveOnly.status).assertEqual(ArticleOfflineStatus.INTERACTIVE_NEEDS_NETWORK);
      expect(interactiveOnly.badgeText).assertEqual('互动部分需联网');

      const both = evaluateOfflineReadiness(5, 3, true);
      expect(both.status).assertEqual(ArticleOfflineStatus.MISSING_IMAGES_AND_INTERACTIVE);
      expect(both.badgeText).assertEqual('仍缺 2 张图 · 互动部分需联网');

      const interactiveDoc = new ScpArticleDocument(
        'SCP-3125',
        '逃逸者',
        'Keter',
        'https://scp-wiki-cn.wikidot.com/scp-3125',
        100,
        [],
        [],
        '',
        ['interactive:html-block-iframe'],
        '+100',
        [],
        '1',
        [],
        []
      );
      expect(requiresNetworkForInteractiveDocument(interactiveDoc)).assertTrue();
    });

    it('opens shelf body and images from v1 beside cached v2, then publishes the confirmed update', 0, async () => {
      const scenario = new ShelfScenario();
      await scenario.open(false);
      expect(scenario.vm.document?.title).assertEqual('v2');
      scenario.vm.setRouteContent(scenario.content, true);
      await drainMicrotasks();
      expect(scenario.vm.document?.title).assertEqual('v1');
      expect(scenario.vm.resolveLocalImageUri(`${REVISION_URL}/v1.png`).startsWith('file://')).assertTrue();
      expect(scenario.vm.resolveLocalImageUri(`${REVISION_URL}/v2.png`)).assertEqual('');
      expect(scenario.html.requests.length).assertEqual(0);

      const updated = await scenario.vm.saveForOffline(ArticleOfflineSaveAction.UPDATE);
      expect(scenario.html.requests.length).assertEqual(1);
      expect(scenario.html.requests[0]).assertTrue();
      expect(scenario.store.requireAllImages).assertTrue();
      expect(updated?.title).assertEqual('v2');
      expect(scenario.vm.document?.title).assertEqual('v2');
      expect(scenario.vm.resolveLocalImageUri(`${REVISION_URL}/v2.png`).startsWith('file://')).assertTrue();
      expect((await scenario.store.loadDocument(scenario.content))?.rawPayloadJson).assertEqual('"v2"');
      scenario.vm.dispose();
    });

    it('keeps the old shelf revision when a forced request yields stale HTML or the fallback archive', 0, async () => {
      const scenario = new ShelfScenario();
      await scenario.open(true);
      scenario.html.source = ArticleHtmlSource.STALE_CACHE;
      for (let index = 0; index < 2; index++) {
        scenario.html.fail = index === 1;
        let failure = '';
        try {
          await scenario.vm.saveForOffline(ArticleOfflineSaveAction.UPDATE);
        } catch (error) {
          failure = (error as Error).message;
        }
        expect(failure.includes('已保留原离线副本')).assertTrue();
        expect(scenario.vm.document?.title).assertEqual('v1');
        expect(scenario.vm.offlineSnapshot?.title).assertEqual('v1');
        expect(scenario.store.saveCount).assertEqual(1);
      }
      scenario.vm.dispose();
    });

    it('accepts a conditionally confirmed page through the compatibility extractor', 0, async () => {
      const scenario = new ShelfScenario();
      await scenario.open(true);
      scenario.html.source = ArticleHtmlSource.FRESH_CACHE;
      scenario.parser.useWebExtractor = true;
      const saving = scenario.vm.saveForOffline(ArticleOfflineSaveAction.UPDATE);
      await drainMicrotasks();
      expect(scenario.vm.document?.title).assertEqual('v1');
      expect(scenario.vm.pendingExtraction?.html).assertEqual('v2');
      scenario.vm.onExtractionResult(scenario.vm.pendingExtraction!.requestId, '"v2"');
      expect((await saving)?.title).assertEqual('v2');
      expect(scenario.store.saveCount).assertEqual(2);
      scenario.vm.dispose();
    });

    it('repairs the saved revision even when the ordinary reader is showing a newer document', 0, async () => {
      const scenario = new ShelfScenario();
      await scenario.open(false);
      const repaired = await scenario.vm.saveForOffline(ArticleOfflineSaveAction.REPAIR_IMAGES);
      expect(scenario.html.requests.length).assertEqual(0);
      expect(scenario.store.requireAllImages).assertFalse();
      expect(repaired?.title).assertEqual('v1');
      expect(scenario.vm.document?.title).assertEqual('v2');
      expect((await scenario.store.loadDocument(scenario.content))?.rawPayloadJson).assertEqual('"v1"');
      scenario.vm.dispose();
    });

    it('loads saved offline archive when temporary document cache is cleared and resolves local image URIs', 0, async () => {
      const doc = makeSample2521Document();
      const htmlPort = new OfflineMemoryHtmlPort();
      const store = new MemoryOfflineStore();
      const gateway = new ContentGateway(htmlPort, new EmptyDocCachePort(), new StaticDocParserPort(doc), store);
      const useCase = new ArticleContentUseCase(gateway, undefined, store);
      const viewModel = new ArticleViewModel(useCase);
      const content = createLibraryContentRef(LibraryContentKind.SCP, 'scp-2521', '●●|●●●●●|●●|●');

      viewModel.setRouteContent(content);
      viewModel.activate();
      await drainMicrotasks();

      expect(viewModel.document?.itemId).assertEqual('SCP-2521');
      const savedSnapshot = await viewModel.saveForOffline();
      expect(savedSnapshot?.badgeText).assertEqual('正文与图片已就绪');
      expect(savedSnapshot?.savedImages).assertEqual(2);
      expect(viewModel.resolveLocalImageUri('http://scp-wiki.wdfiles.com/local--files/scp-2521/b.png\r').startsWith('file://')).assertTrue();

      // Simulate clearing temporary caches and losing network, then verify gateway source + cold reopen.
      htmlPort.fail = true;
      const gatewayResult = await gateway.load(content, 77, false);
      expect(gatewayResult.source).assertEqual(ArticleContentSource.OFFLINE_ARCHIVE);
      expect(gatewayResult.stale).assertFalse();
      expect(gatewayResult.document?.itemId).assertEqual('SCP-2521');

      const coldViewModel = new ArticleViewModel(useCase);
      coldViewModel.setRouteContent(content);
      coldViewModel.activate();
      await drainMicrotasks();

      expect(coldViewModel.document?.itemId).assertEqual('SCP-2521');
      expect(coldViewModel.offlineSnapshot?.badgeText).assertEqual('正文与图片已就绪');
      expect(coldViewModel.resolveLocalImageUri('http://scp-wiki.wdfiles.com/local--files/scp-2521/a.png').startsWith('file://')).assertTrue();

      viewModel.dispose();
      coldViewModel.dispose();
    });
  });
}
