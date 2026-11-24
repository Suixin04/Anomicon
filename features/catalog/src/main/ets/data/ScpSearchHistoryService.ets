import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const PREFERENCES_NAME: string = 'anomicon_search';
const HISTORY_KEY: string = 'catalog_search_history_native';
const MAX_HISTORY: number = 10;

interface SearchHistoryPreferenceValues {
  catalog_search_history_native?: preferences.ValueType;
}

/** A write returns only after the new list is durable. */
export interface SearchHistoryStorage {
  discardCache(): void;
  read(): preferences.ValueType | undefined;
  write(items: string[]): void;
}

class PreferencesSearchHistoryStorage implements SearchHistoryStorage {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  discardCache(): void {
    preferences.removePreferencesFromCacheSync(this.context, PREFERENCES_NAME);
  }

  read(): preferences.ValueType | undefined {
    const store = preferences.getPreferencesSync(this.context, { name: PREFERENCES_NAME });
    const values = store.getAllSync() as SearchHistoryPreferenceValues;
    return values.catalog_search_history_native;
  }

  write(items: string[]): void {
    const store = preferences.getPreferencesSync(this.context, { name: PREFERENCES_NAME });
    if (items.length === 0) {
      store.deleteSync(HISTORY_KEY);
    } else {
      store.putSync(HISTORY_KEY, items);
    }
    store.flushSync();
  }
}

/** 搜索历史：本地 preferences 持久化，最近 10 条、去重、可清空。 */
export class ScpSearchHistoryService {
  private readonly storage: SearchHistoryStorage;
  private items: string[] = [];
  private loaded: boolean = false;
  private needsFreshCache: boolean = true;
  private dirty: boolean = false;

  constructor(storage: SearchHistoryStorage) {
    this.storage = storage;
  }

  static forContext(context: common.UIAbilityContext): ScpSearchHistoryService {
    return new ScpSearchHistoryService(new PreferencesSearchHistoryStorage(context));
  }

  initialize(): void {
    if (this.dirty) {
      this.saveAdditions();
      return;
    }
    if (!this.loaded) {
      try {
        this.prepareStorage();
        const stored = this.storage.read();
        this.items = Array.isArray(stored) ? this.normalizeItems(stored as string[]) : [];
        this.loaded = true;
      } catch (error) {
        console.warn(`Read search history failed: ${error instanceof Error ? error.message : 'unknown error'}`);
      }
    }
  }

  list(): string[] {
    this.initialize();
    return this.items.slice();
  }

  add(query: string): void {
    this.initialize();
    const value = query.trim();
    if (value.length === 0) {
      return;
    }
    const index = this.items.indexOf(value);
    if (index >= 0) {
      this.items.splice(index, 1);
    }
    this.items.unshift(value);
    if (this.items.length > MAX_HISTORY) {
      this.items.length = MAX_HISTORY;
    }
    this.saveAdditions();
  }

  clear(): void {
    // A failed deletion leaves the visible list intact so either page can retry.
    this.persist([]);
    this.items = [];
    this.dirty = false;
    this.loaded = true;
  }

  private prepareStorage(): void {
    if (this.needsFreshCache) {
      this.storage.discardCache();
      this.needsFreshCache = false;
    }
  }

  private persist(items: string[]): void {
    this.prepareStorage();
    // A failed flush can consume the SDK's dirty keys. Retry from disk so an
    // already edited cache cannot make the next flush skip the write.
    this.needsFreshCache = true;
    this.storage.write(items);
    this.needsFreshCache = false;
  }

  private saveAdditions(): void {
    try {
      this.persist(this.items.slice());
      this.loaded = true;
      this.dirty = false;
    } catch (error) {
      // Keep newly entered queries usable and retry their write on the next read.
      this.dirty = true;
      console.warn(`Save search history failed: ${error instanceof Error ? error.message : 'unknown error'}`);
    }
  }

  private normalizeItems(values: string[]): string[] {
    const normalized: string[] = [];
    for (const item of values) {
      if (typeof item !== 'string') {
        continue;
      }
      const value = item.trim();
      if (value.length === 0 || normalized.includes(value)) {
        continue;
      }
      normalized.push(value);
      if (normalized.length >= MAX_HISTORY) {
        break;
      }
    }
    return normalized;
  }
}
