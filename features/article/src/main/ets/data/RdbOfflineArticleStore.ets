import { common } from '@kit.AbilityKit';
import { ArkTSUtils, util } from '@kit.ArkTS';
import { relationalStore } from '@kit.ArkData';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { ANOMICON_DATABASE_NAME } from 'anomiconbasic';
import { LibraryContentKind, LibraryContentRef } from 'library';
import {
  ArticleDocumentParserPort
} from '../domain/ArticleContracts';
import {
  ArticleOfflineDocumentRecord,
  ArticleOfflineImageEntry,
  ArticleOfflineImageFetcher,
  ArticleOfflineSaveProgress,
  ArticleOfflineSnapshot,
  ArticleOfflineStoragePort,
  ArticleOfflineStoreListener,
  ArticleOfflineSummary,
  collectArticleImageUrls,
  evaluateOfflineReadiness,
  normalizeOfflineImageUrl,
  requiresNetworkForInteractiveDocument
} from '../domain/ArticleOfflineContracts';
import { ScpArticleDocument } from '../domain/ScpDocument';

const TABLE_NAME: string = 'offline_articles';
const CREATE_OFFLINE_TABLE: string =
  'CREATE TABLE IF NOT EXISTS offline_articles (' +
  'content_key TEXT PRIMARY KEY, ' +
  'content_kind TEXT NOT NULL, ' +
  'item_id TEXT NOT NULL, ' +
  'title TEXT NOT NULL, ' +
  'source_url TEXT NOT NULL, ' +
  'schema_version INTEGER NOT NULL, ' +
  'document_path TEXT NOT NULL, ' +
  'manifest_json TEXT NOT NULL, ' +
  'total_images INTEGER NOT NULL, ' +
  'saved_images INTEGER NOT NULL, ' +
  'requires_network_interactive INTEGER NOT NULL, ' +
  'total_bytes INTEGER NOT NULL, ' +
  'saved_at INTEGER NOT NULL)';

const TEXT_READ_CHUNK_BYTES: number = 256 * 1024;
const MAX_DOCUMENT_BYTES: number = 64 * 1024 * 1024;
const IMAGE_DOWNLOAD_CONCURRENCY: number = 3;

interface StoredOfflineRow {
  readonly contentKey: string;
  readonly contentKind: LibraryContentKind;
  readonly itemId: string;
  readonly title: string;
  readonly sourceUrl: string;
  readonly schemaVersion: number;
  readonly documentPath: string;
  readonly manifestJson: string;
  readonly totalImages: number;
  readonly savedImages: number;
  readonly requiresNetworkInteractive: boolean;
  readonly totalBytes: number;
  readonly savedAt: number;
}

interface VerifiedManifestResult {
  readonly snapshot: ArticleOfflineSnapshot;
  readonly summary: ArticleOfflineSummary;
}

interface ImageDownloadSlot {
  readonly index: number;
  readonly url: string;
}

/**
 * Permanent per-article offline vault backed by SQLite metadata (`offline_articles`) and
 * immutable files under `applicationContext.filesDir/offline_articles/v1/<safeKey>/`.
 * Isolated from `cacheDir` temporary caches so Settings cache cleanup never deletes saved articles.
 */
export class RdbOfflineArticleStore implements ArticleOfflineStoragePort {
  private readonly context: common.UIAbilityContext;
  private readonly parser: ArticleDocumentParserPort;
  private readonly imageFetcher: ArticleOfflineImageFetcher | undefined;
  private readonly filesDir: string;
  private readonly vaultRootDir: string;
  private readonly encoder: util.TextEncoder = util.TextEncoder.create('utf-8');
  private readonly decoder: util.TextDecoder = util.TextDecoder.create('utf-8', {
    fatal: true,
    ignoreBOM: false
  });
  private readonly operationLock: ArkTSUtils.locks.AsyncLock =
    new ArkTSUtils.locks.AsyncLock();
  private readonly activeMutationKeys: Set<string> = new Set();
  private readonly listeners: ArticleOfflineStoreListener[] = [];
  private store: relationalStore.RdbStore | undefined = undefined;
  private initialization: Promise<void> | undefined = undefined;

  constructor(
    context: common.UIAbilityContext,
    parser: ArticleDocumentParserPort,
    imageFetcher?: ArticleOfflineImageFetcher
  ) {
    this.context = context;
    this.parser = parser;
    this.imageFetcher = imageFetcher;
    this.filesDir = context.getApplicationContext().filesDir;
    this.vaultRootDir = `${this.filesDir}/offline_articles/v1`;
  }

  initialize(): Promise<void> {
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    this.initialization = this.open();
    return this.initialization;
  }

  subscribe(listener: ArticleOfflineStoreListener): () => void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
    return (): void => {
      const idx = this.listeners.indexOf(listener);
      if (idx >= 0) {
        this.listeners.splice(idx, 1);
      }
    };
  }

  async inspect(content: LibraryContentRef): Promise<ArticleOfflineSnapshot | undefined> {
    let snapshot: ArticleOfflineSnapshot | undefined = undefined;
    await this.enqueueOperation(async (): Promise<void> => {
      const row = await this.findRowNow(content);
      if (row === undefined) {
        return;
      }
      const verified = await this.verifyRowOnDisk(row);
      snapshot = verified?.snapshot;
    });
    return snapshot;
  }

  async loadDocument(content: LibraryContentRef): Promise<ArticleOfflineDocumentRecord | undefined> {
    let record: ArticleOfflineDocumentRecord | undefined = undefined;
    await this.enqueueOperation(async (): Promise<void> => {
      const row = await this.findRowNow(content);
      if (row === undefined) {
        return;
      }
      const verified = await this.verifyRowOnDisk(row);
      if (verified === undefined) {
        return;
      }
      const payloadJson = await this.readTextFile(row.documentPath);
      if (payloadJson === undefined || payloadJson.length === 0) {
        return;
      }
      try {
        const document = this.parser.parse(payloadJson, row.sourceUrl, row.savedAt);
        record = {
          document,
          rawPayloadJson: payloadJson,
          savedAt: row.savedAt,
          snapshot: verified.snapshot
        };
      } catch (error) {
        console.warn(`Parse offline document failed (${row.itemId}): ${this.errorMessage(error)}`);
      }
    });
    return record;
  }

  async save(
    content: LibraryContentRef,
    document: ScpArticleDocument,
    rawPayloadJson: string,
    onProgress?: (progress: ArticleOfflineSaveProgress) => void,
    refreshAllImages: boolean = false
  ): Promise<ArticleOfflineSnapshot> {
    this.beginMutation(content.key);
    let unpublishedDir: string = '';
    try {
      await this.initialize();
      const sourceUrl = document.sourceUrl.length > 0 ?
        document.sourceUrl : `https://scp-wiki-cn.wikidot.com/${content.id.toLowerCase()}`;
      const savedAt = Date.now();
      const payload = rawPayloadJson.trim();
      if (payload.length === 0) {
        throw new Error('当前正文数据未就绪，请刷新文章后再保存');
      }
      // Derive the manifest from the exact bytes the reader will reopen.
      const savedDocument = this.parser.parse(payload, sourceUrl, savedAt);
      const safeDirName = this.safeDirectoryName(content.key);
      const articleDir = `${this.vaultRootDir}/${safeDirName}`;
      const version = `version-${util.generateRandomUUID(true).toLowerCase()}`;
      unpublishedDir = `${articleDir}/${version}`;
      const imagesDir = `${unpublishedDir}/images`;
      const documentPath = `${unpublishedDir}/document.json`;
      await this.ensureDirectoryChain(['offline_articles', 'v1', safeDirName, version, 'images']);

      let previousImagesDir = '';
      const existingFileByUrl: Map<string, string> = new Map();
      if (!refreshAllImages) {
        await this.enqueueOperation(async (): Promise<void> => {
          const previous = await this.findRowNow(content);
          if (previous === undefined) {
            return;
          }
          previousImagesDir = `${previous.documentPath.substring(0, previous.documentPath.lastIndexOf('/'))}/images`;
          const prevManifest = this.parseManifest(previous.manifestJson);
          for (const entry of prevManifest) {
            if (entry.saved && entry.fileName.length > 0) {
              existingFileByUrl.set(entry.url, entry.fileName);
            }
          }
        });
      }

      const imageUrls = collectArticleImageUrls(savedDocument);
      const totalImages = imageUrls.length;
      const results: ArticleOfflineImageEntry[] = new Array(totalImages);
      const pendingSlots: ImageDownloadSlot[] = [];
      let completedImages: number = 0;

      for (let index = 0; index < totalImages; index++) {
        const imageUrl = imageUrls[index];
        const prevName = existingFileByUrl.get(imageUrl) ?? '';
        if (prevName.length > 0) {
          const previousImage = `${previousImagesDir}/${prevName}`;
          const existingSize = await this.regularFileSize(previousImage);
          if (existingSize > 0) {
            await this.copyFileAtomically(previousImage, `${imagesDir}/${prevName}`);
            results[index] = {
              url: imageUrl,
              fileName: prevName,
              bytes: existingSize,
              saved: true
            };
            completedImages++;
            continue;
          }
        }
        pendingSlots.push({
          index,
          url: imageUrl
        });
      }

      onProgress?.({ completedImages, totalImages });

      if (pendingSlots.length > 0) {
        let nextSlotIndex: number = 0;
        const workerCount = Math.min(IMAGE_DOWNLOAD_CONCURRENCY, pendingSlots.length);
        const runWorker = async (): Promise<void> => {
          while (nextSlotIndex < pendingSlots.length) {
            const slot = pendingSlots[nextSlotIndex++];
            const entry = await this.fetchAndPersistImage(slot.url, imagesDir, refreshAllImages);
            results[slot.index] = entry;
            completedImages++;
            onProgress?.({ completedImages, totalImages });
          }
        };
        const workers: Promise<void>[] = [];
        for (let index = 0; index < workerCount; index++) {
          workers.push(runWorker());
        }
        await Promise.all(workers);
      }

      await this.writeTextFileAtomically(documentPath, payload);
      const docBytes = await this.regularFileSize(documentPath);
      if (docBytes <= 0) {
        throw new Error('离线正文写入验证失败');
      }

      let savedImages: number = 0;
      let totalImageBytes: number = 0;
      const localImageUris: Map<string, string> = new Map();
      for (let index = 0; index < results.length; index++) {
        const entry = results[index];
        if (entry.saved && entry.fileName.length > 0) {
          const fullImagePath = `${imagesDir}/${entry.fileName}`;
          const verifiedBytes = await this.regularFileSize(fullImagePath);
          if (verifiedBytes > 0) {
            results[index] = {
              url: entry.url,
              fileName: entry.fileName,
              bytes: verifiedBytes,
              saved: true
            };
            savedImages++;
            totalImageBytes += verifiedBytes;
            localImageUris.set(entry.url, fileUri.getUriFromPath(fullImagePath));
            continue;
          }
        }
        results[index] = {
          url: entry.url,
          fileName: entry.fileName,
          bytes: 0,
          saved: false
        };
      }

      if (refreshAllImages && savedImages < totalImages) {
        throw new Error(`更新副本失败，仍缺 ${totalImages - savedImages} 张图。已保留原副本，请稍后重试`);
      }
      const requiresInteractive = requiresNetworkForInteractiveDocument(savedDocument);
      const readiness = evaluateOfflineReadiness(totalImages, savedImages, requiresInteractive);
      const totalBytes = docBytes + totalImageBytes;
      const title = savedDocument.title.trim().length > 0 ? savedDocument.title.trim() : content.title;
      const manifestJson = JSON.stringify(results);

      const row: StoredOfflineRow = {
        contentKey: content.key,
        contentKind: content.kind,
        itemId: content.id,
        title,
        sourceUrl,
        schemaVersion: this.parser.currentSchemaVersion(),
        documentPath,
        manifestJson,
        totalImages,
        savedImages,
        requiresNetworkInteractive: requiresInteractive,
        totalBytes,
        savedAt
      };
      await this.enqueueOperation(async (): Promise<void> => {
        // One SQLite row publishes the document path and its image manifest together.
        await this.upsertRowNow(row);
        unpublishedDir = '';
      });
      await this.removeSupersededVersions(articleDir, version);
      this.notifyListeners();

      return new ArticleOfflineSnapshot(
        row.contentKey,
        row.contentKind,
        row.itemId,
        row.title,
        row.sourceUrl,
        row.savedAt,
        totalBytes,
        totalImages,
        savedImages,
        readiness.missingImages,
        requiresInteractive,
        readiness.status,
        readiness.badgeText,
        readiness.detailText,
        localImageUris
      );
    } finally {
      if (unpublishedDir.length > 0) {
        await this.removeDirectoryRecursive(unpublishedDir);
      }
      this.activeMutationKeys.delete(content.key);
    }
  }

  private beginMutation(key: string): void {
    if (this.activeMutationKeys.has(key)) {
      throw new Error('正在处理该文章的离线副本，请稍后再试');
    }
    this.activeMutationKeys.add(key);
  }

  async remove(contentKey: string): Promise<void> {
    this.beginMutation(contentKey);
    try {
      await this.removeNow(contentKey);
    } finally {
      this.activeMutationKeys.delete(contentKey);
    }
  }

  private async removeNow(contentKey: string): Promise<void> {
    const safeDirName = this.safeDirectoryName(contentKey);
    const articleDir = `${this.vaultRootDir}/${safeDirName}`;
    let existingDocPath: string = '';
    await this.enqueueOperation(async (): Promise<void> => {
      const store = await this.requireStore();
      const lookup = new relationalStore.RdbPredicates(TABLE_NAME);
      lookup.equalTo('content_key', contentKey);
      let resultSet: relationalStore.ResultSet | undefined = undefined;
      try {
        resultSet = await store.query(lookup, ['document_path']);
        if (resultSet.goToFirstRow()) {
          existingDocPath = resultSet.getString(resultSet.getColumnIndex('document_path'));
        }
      } catch (error) {
        throw this.storeError('查询删除目标', error);
      } finally {
        this.closeResultSet(resultSet);
      }
      const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
      predicates.equalTo('content_key', contentKey);
      try {
        await store.delete(predicates);
      } catch (error) {
        throw this.storeError('移除记录', error);
      }
    });
    await this.removeDirectoryRecursive(articleDir);
    if (existingDocPath.length > 0) {
      const parentSlash = existingDocPath.lastIndexOf('/');
      const storedDir = parentSlash > 0 ? existingDocPath.substring(0, parentSlash) : '';
      if (storedDir.length > 0 && storedDir !== articleDir && storedDir.startsWith(this.vaultRootDir)) {
        await this.removeDirectoryRecursive(storedDir);
      }
    }
    this.notifyListeners();
  }

  async listSummaries(): Promise<ArticleOfflineSummary[]> {
    const summaries: ArticleOfflineSummary[] = [];
    await this.enqueueOperation(async (): Promise<void> => {
      const rows = await this.listRowsNow();
      for (let index = 0; index < rows.length; index++) {
        const verified = await this.verifyRowOnDisk(rows[index]);
        if (verified !== undefined) {
          summaries.push(verified.summary);
        }
      }
    });
    return summaries;
  }

  private async open(): Promise<void> {
    try {
      await this.ensureDirectoryChain(['offline_articles', 'v1']);
      const store = await relationalStore.getRdbStore(this.context, {
        name: ANOMICON_DATABASE_NAME,
        securityLevel: relationalStore.SecurityLevel.S1,
        encrypt: false
      });
      await store.executeSql(CREATE_OFFLINE_TABLE);
      this.store = store;
    } catch (error) {
      this.initialization = undefined;
      throw this.storeError('初始化', error);
    }
  }

  private async requireStore(): Promise<relationalStore.RdbStore> {
    await this.initialize();
    if (this.store === undefined) {
      throw new Error('离线文章存储尚未初始化');
    }
    return this.store;
  }

  private async findRowNow(content: LibraryContentRef): Promise<StoredOfflineRow | undefined> {
    const store = await this.requireStore();
    const byKey = new relationalStore.RdbPredicates(TABLE_NAME);
    byKey.equalTo('content_key', content.key);
    byKey.limitAs(1);
    const keyRow = await this.querySingleRow(store, byKey);
    if (keyRow !== undefined) {
      return keyRow;
    }
    const byItemId = new relationalStore.RdbPredicates(TABLE_NAME);
    byItemId.equalTo('item_id', content.id);
    byItemId.limitAs(1);
    return this.querySingleRow(store, byItemId);
  }

  private async listRowsNow(): Promise<StoredOfflineRow[]> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.orderByDesc('saved_at');
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    const rows: StoredOfflineRow[] = [];
    try {
      resultSet = await store.query(predicates, [
        'content_key',
        'content_kind',
        'item_id',
        'title',
        'source_url',
        'schema_version',
        'document_path',
        'manifest_json',
        'total_images',
        'saved_images',
        'requires_network_interactive',
        'total_bytes',
        'saved_at'
      ]);
      while (resultSet.goToNextRow()) {
        rows.push(this.readRow(resultSet));
      }
      return rows;
    } catch (error) {
      throw this.storeError('读取列表', error);
    } finally {
      this.closeResultSet(resultSet);
    }
  }

  private async querySingleRow(
    store: relationalStore.RdbStore,
    predicates: relationalStore.RdbPredicates
  ): Promise<StoredOfflineRow | undefined> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await store.query(predicates, [
        'content_key',
        'content_kind',
        'item_id',
        'title',
        'source_url',
        'schema_version',
        'document_path',
        'manifest_json',
        'total_images',
        'saved_images',
        'requires_network_interactive',
        'total_bytes',
        'saved_at'
      ]);
      if (!resultSet.goToFirstRow()) {
        return undefined;
      }
      return this.readRow(resultSet);
    } catch (error) {
      throw this.storeError('查询', error);
    } finally {
      this.closeResultSet(resultSet);
    }
  }

  private readRow(resultSet: relationalStore.ResultSet): StoredOfflineRow {
    return {
      contentKey: resultSet.getString(resultSet.getColumnIndex('content_key')),
      contentKind: this.normalizeContentKind(
        resultSet.getString(resultSet.getColumnIndex('content_kind'))
      ),
      itemId: resultSet.getString(resultSet.getColumnIndex('item_id')),
      title: resultSet.getString(resultSet.getColumnIndex('title')),
      sourceUrl: resultSet.getString(resultSet.getColumnIndex('source_url')),
      schemaVersion: resultSet.getLong(resultSet.getColumnIndex('schema_version')),
      documentPath: resultSet.getString(resultSet.getColumnIndex('document_path')),
      manifestJson: resultSet.getString(resultSet.getColumnIndex('manifest_json')),
      totalImages: resultSet.getLong(resultSet.getColumnIndex('total_images')),
      savedImages: resultSet.getLong(resultSet.getColumnIndex('saved_images')),
      requiresNetworkInteractive:
        resultSet.getLong(resultSet.getColumnIndex('requires_network_interactive')) !== 0,
      totalBytes: resultSet.getLong(resultSet.getColumnIndex('total_bytes')),
      savedAt: resultSet.getLong(resultSet.getColumnIndex('saved_at'))
    };
  }

  private async upsertRowNow(row: StoredOfflineRow): Promise<void> {
    const store = await this.requireStore();
    const values: relationalStore.ValuesBucket = {
      'content_key': row.contentKey,
      'content_kind': row.contentKind,
      'item_id': row.itemId,
      'title': row.title,
      'source_url': row.sourceUrl,
      'schema_version': row.schemaVersion,
      'document_path': row.documentPath,
      'manifest_json': row.manifestJson,
      'total_images': row.totalImages,
      'saved_images': row.savedImages,
      'requires_network_interactive': row.requiresNetworkInteractive ? 1 : 0,
      'total_bytes': row.totalBytes,
      'saved_at': row.savedAt
    };
    try {
      const rowId = await store.insert(
        TABLE_NAME,
        values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
      if (rowId < 0) {
        throw new Error(`写入离线档案失败：${row.itemId}`);
      }
    } catch (error) {
      throw this.storeError('保存元数据', error);
    }
  }

  private async verifyRowOnDisk(row: StoredOfflineRow): Promise<VerifiedManifestResult | undefined> {
    if (row.schemaVersion <= 0 || row.schemaVersion > this.parser.currentSchemaVersion()) {
      return undefined;
    }
    const docSize = await this.regularFileSize(row.documentPath);
    if (docSize <= 0) {
      return undefined;
    }
    const slashIndex = row.documentPath.lastIndexOf('/');
    const articleDir = slashIndex > 0 ? row.documentPath.substring(0, slashIndex) : '';
    const imagesDir = articleDir.length > 0 ? `${articleDir}/images` : '';

    const manifest = this.parseManifest(row.manifestJson);
    const totalImages = manifest.length > 0 ? manifest.length : Math.max(0, row.totalImages);
    let savedImages: number = 0;
    let totalImageBytes: number = 0;
    const localImageUris: Map<string, string> = new Map();

    for (let index = 0; index < manifest.length; index++) {
      const entry = manifest[index];
      if (!entry.saved || entry.fileName.length === 0 || imagesDir.length === 0) {
        continue;
      }
      const imagePath = `${imagesDir}/${entry.fileName}`;
      const size = await this.regularFileSize(imagePath);
      if (size > 0) {
        savedImages++;
        totalImageBytes += size;
        const normalizedUrl = normalizeOfflineImageUrl(entry.url, row.sourceUrl);
        const mapKey = normalizedUrl.length > 0 ? normalizedUrl : entry.url;
        localImageUris.set(mapKey, fileUri.getUriFromPath(imagePath));
      }
    }

    const readiness = evaluateOfflineReadiness(
      totalImages,
      savedImages,
      row.requiresNetworkInteractive
    );
    const totalBytes = docSize + totalImageBytes;
    const snapshot = new ArticleOfflineSnapshot(
      row.contentKey,
      row.contentKind,
      row.itemId,
      row.title,
      row.sourceUrl,
      row.savedAt,
      totalBytes,
      totalImages,
      savedImages,
      readiness.missingImages,
      row.requiresNetworkInteractive,
      readiness.status,
      readiness.badgeText,
      readiness.detailText,
      localImageUris
    );
    const summary = new ArticleOfflineSummary(
      row.contentKey,
      row.contentKind,
      row.itemId,
      row.title,
      row.sourceUrl,
      row.savedAt,
      totalBytes,
      totalImages,
      savedImages,
      readiness.missingImages,
      row.requiresNetworkInteractive,
      readiness.status,
      readiness.badgeText,
      readiness.detailText
    );
    return { snapshot, summary };
  }

  private async fetchAndPersistImage(
    url: string,
    imagesDir: string,
    forceNetwork: boolean
  ): Promise<ArticleOfflineImageEntry> {
    if (this.imageFetcher === undefined) {
      return { url, fileName: '', bytes: 0, saved: false };
    }
    try {
      const cachedPath = await this.imageFetcher.fetchToLocalFile(url, forceNetwork);
      if (cachedPath.length === 0) {
        return { url, fileName: '', bytes: 0, saved: false };
      }
      const sourceSize = await this.regularFileSize(cachedPath);
      if (sourceSize <= 0) {
        return { url, fileName: '', bytes: 0, saved: false };
      }
      const ext = this.extensionFromPath(cachedPath);
      const fileName = `${this.doubleHashHex(url)}.${ext}`;
      const finalPath = `${imagesDir}/${fileName}`;
      await this.copyFileAtomically(cachedPath, finalPath);
      const savedSize = await this.regularFileSize(finalPath);
      if (savedSize <= 0) {
        return { url, fileName: '', bytes: 0, saved: false };
      }
      return { url, fileName, bytes: savedSize, saved: true };
    } catch (error) {
      console.warn(`Save offline image failed (${url}): ${this.errorMessage(error)}`);
      return { url, fileName: '', bytes: 0, saved: false };
    }
  }

  private async copyFileAtomically(sourcePath: string, destinationPath: string): Promise<void> {
    const tempId = util.generateRandomUUID(true).toLowerCase();
    const temporaryPath = `${destinationPath}.${tempId}.tmp`;
    let sourceFile: fs.File | undefined = undefined;
    let destinationFile: fs.File | undefined = undefined;
    try {
      sourceFile = await fs.open(sourcePath, fs.OpenMode.READ_ONLY | fs.OpenMode.NOFOLLOW);
      destinationFile = await fs.open(
        temporaryPath,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC | fs.OpenMode.NOFOLLOW
      );
      await fs.copyFile(sourceFile.fd, destinationFile.fd);
      await fs.fsync(destinationFile.fd);
      await fs.close(sourceFile);
      sourceFile = undefined;
      await fs.close(destinationFile);
      destinationFile = undefined;
      await fs.rename(temporaryPath, destinationPath);
    } finally {
      await this.closeFileQuietly(sourceFile);
      await this.closeFileQuietly(destinationFile);
      await this.unlinkIfExistsQuietly(temporaryPath);
    }
  }

  private async writeTextFileAtomically(filePath: string, text: string): Promise<void> {
    const bytes = this.encoder.encodeInto(text);
    if (bytes.byteLength <= 0 || bytes.byteLength > MAX_DOCUMENT_BYTES) {
      throw new Error(`离线正文大小无效：${bytes.byteLength}`);
    }
    const tempId = util.generateRandomUUID(true).toLowerCase();
    const temporaryPath = `${filePath}.${tempId}.tmp`;
    let file: fs.File | undefined = undefined;
    try {
      file = await fs.open(
        temporaryPath,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC | fs.OpenMode.NOFOLLOW
      );
      const written = await fs.write(file.fd, bytes.buffer as ArrayBuffer);
      if (written !== bytes.byteLength) {
        throw new Error(`离线正文写入不完整：${written}/${bytes.byteLength}`);
      }
      await fs.fsync(file.fd);
      await fs.close(file);
      file = undefined;
      await fs.rename(temporaryPath, filePath);
    } finally {
      await this.closeFileQuietly(file);
      await this.unlinkIfExistsQuietly(temporaryPath);
    }
  }

  private async readTextFile(filePath: string): Promise<string | undefined> {
    let file: fs.File | undefined = undefined;
    try {
      if (!(await fs.access(filePath))) {
        return undefined;
      }
      const stat = await fs.stat(filePath);
      if (!stat.isFile() || stat.size <= 0 || stat.size > MAX_DOCUMENT_BYTES) {
        return undefined;
      }
      file = await fs.open(filePath, fs.OpenMode.READ_ONLY | fs.OpenMode.NOFOLLOW);
      const output = new Uint8Array(stat.size);
      let offset: number = 0;
      while (offset < stat.size) {
        const chunkLength = Math.min(TEXT_READ_CHUNK_BYTES, stat.size - offset);
        const chunk = new ArrayBuffer(chunkLength);
        const read = await fs.read(file.fd, chunk);
        if (read <= 0 || read > chunkLength) {
          return undefined;
        }
        output.set(new Uint8Array(chunk, 0, read), offset);
        offset += read;
      }
      return this.decoder.decodeToString(output, { stream: false });
    } catch (_error) {
      return undefined;
    } finally {
      await this.closeFileQuietly(file);
    }
  }

  private async ensureDirectoryChain(segments: string[]): Promise<void> {
    let current = this.filesDir;
    for (let index = 0; index < segments.length; index++) {
      current = `${current}/${segments[index]}`;
      if (!(await fs.access(current))) {
        try {
          await fs.mkdir(current);
        } catch (error) {
          if (!(await fs.access(current))) {
            throw new Error(this.errorMessage(error));
          }
        }
      }
    }
  }

  private async regularFileSize(filePath: string): Promise<number> {
    try {
      if (!(await fs.access(filePath))) {
        return 0;
      }
      const stat = await fs.lstat(filePath);
      if (stat.isSymbolicLink() || !stat.isFile()) {
        return 0;
      }
      return stat.size > 0 ? stat.size : 0;
    } catch (_error) {
      return 0;
    }
  }

  /** After publication, reclaim old versions (including any left by an interrupted save).
   * The pre-versioned archive had its document and images directly under articleDir. */
  private async removeSupersededVersions(articleDir: string, publishedVersion: string): Promise<void> {
    try {
      const names = await fs.listFile(articleDir);
      for (let index = 0; index < names.length; index++) {
        const name = names[index];
        if (name === 'document.json') {
          await this.unlinkIfExistsQuietly(`${articleDir}/${name}`);
        } else if (name === 'images' || (name.startsWith('version-') && name !== publishedVersion)) {
          await this.removeDirectoryRecursive(`${articleDir}/${name}`);
        }
      }
    } catch (error) {
      console.warn(`Clean old offline versions failed: ${this.errorMessage(error)}`);
    }
  }

  private async removeDirectoryRecursive(dirPath: string): Promise<void> {
    try {
      if (!(await fs.access(dirPath))) {
        return;
      }
      const names = await fs.listFile(dirPath);
      for (let index = 0; index < names.length; index++) {
        const child = `${dirPath}/${names[index]}`;
        const stat = await fs.lstat(child);
        if (stat.isDirectory() && !stat.isSymbolicLink()) {
          await this.removeDirectoryRecursive(child);
        } else {
          await this.unlinkIfExistsQuietly(child);
        }
      }
      await fs.rmdir(dirPath);
    } catch (_error) {
    }
  }

  private parseManifest(json: string): ArticleOfflineImageEntry[] {
    if (json.trim().length === 0) {
      return [];
    }
    try {
      const decoded = JSON.parse(json) as Object;
      if (!Array.isArray(decoded)) {
        return [];
      }
      const items: ArticleOfflineImageEntry[] = [];
      for (let index = 0; index < decoded.length; index++) {
        const raw = decoded[index] as ArticleOfflineImageEntry;
        if (raw !== undefined && raw !== null && typeof raw === 'object' &&
          typeof raw.url === 'string' && typeof raw.fileName === 'string' &&
          typeof raw.bytes === 'number' && typeof raw.saved === 'boolean') {
          items.push({
            url: raw.url,
            fileName: raw.fileName,
            bytes: raw.bytes,
            saved: raw.saved
          });
        }
      }
      return items;
    } catch (_error) {
      return [];
    }
  }

  private safeDirectoryName(contentKey: string): string {
    const cleaned = contentKey.toLowerCase()
      .replace(/[^a-z0-9_-]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .substring(0, 40);
    const prefix = cleaned.length > 0 ? cleaned : 'article';
    return `${prefix}_${this.doubleHashHex(contentKey)}`;
  }

  private doubleHashHex(input: string): string {
    let h1: number = 0x811c9dc5;
    let h2: number = 0x9e3779b9;
    for (let index = 0; index < input.length; index++) {
      const code = input.charCodeAt(index);
      h1 ^= code;
      h1 = Math.imul(h1, 0x01000193) >>> 0;
      h2 ^= (code + index);
      h2 = Math.imul(h2, 0x85ebca6b) >>> 0;
    }
    return `${h1.toString(16).padStart(8, '0')}${h2.toString(16).padStart(8, '0')}`;
  }

  private extensionFromPath(filePath: string): string {
    const dot = filePath.lastIndexOf('.');
    const slash = filePath.lastIndexOf('/');
    if (dot > slash && dot >= 0) {
      const ext = filePath.substring(dot + 1).toLowerCase();
      if (/^[a-z0-9]{2,6}$/.test(ext)) {
        return ext;
      }
    }
    return 'img';
  }

  private normalizeContentKind(rawKind: string): LibraryContentKind {
    switch (rawKind) {
      case LibraryContentKind.TALE:
        return LibraryContentKind.TALE;
      case LibraryContentKind.KNOWLEDGE:
        return LibraryContentKind.KNOWLEDGE;
      case LibraryContentKind.WIKI:
        return LibraryContentKind.WIKI;
      default:
        return LibraryContentKind.SCP;
    }
  }

  private enqueueOperation(operation: () => Promise<void>): Promise<void> {
    try {
      return this.operationLock.lockAsync<void>(
        operation,
        ArkTSUtils.locks.AsyncLockMode.EXCLUSIVE
      );
    } catch (error) {
      return Promise.reject(error);
    }
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

  private async closeFileQuietly(file: fs.File | undefined): Promise<void> {
    if (file === undefined) {
      return;
    }
    try {
      await fs.close(file);
    } catch (_error) {
    }
  }

  private async unlinkIfExistsQuietly(filePath: string): Promise<void> {
    try {
      if (await fs.access(filePath)) {
        await fs.unlink(filePath);
      }
    } catch (_error) {
    }
  }

  private closeResultSet(resultSet: relationalStore.ResultSet | undefined): void {
    try {
      resultSet?.close();
    } catch (_error) {
    }
  }

  private errorMessage(error: Object): string {
    return error instanceof Error ? error.message : '未知错误';
  }

  private storeError(operation: string, error: Object): Error {
    return new Error(`离线文章存储${operation}失败：${this.errorMessage(error)}`);
  }
}
