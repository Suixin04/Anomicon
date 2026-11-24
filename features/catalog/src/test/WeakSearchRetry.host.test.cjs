// Run from this checkout with the DevEco API 26 SDK and Node.js.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
const path = require('node:path');
const test = require('node:test');
const ts = require(path.join(process.env.DEVECO_SDK_HOME, 'default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'));
const root = path.resolve(__dirname, '../../../..');
const catalog = file => require(path.join(root, 'features/catalog/src/main/ets', `${file}.ets`));
const common = file => require(path.join(root, 'common/anomiconbasic/src/main/ets', `${file}.ets`));

// Use the production parser, search VM, fetcher and scheduler. Supply SDK and storage boundaries on the host.
require.extensions['.ets'] = (module, filename) => {
  const { outputText } = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    fileName: 'input.ts', compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
      experimentalDecorators: true, useDefineForClassFields: false }
  });
  module._compile(outputText, filename);
};
global.ObservedV2 = global.Trace = () => {};
const basic = { ...common('mvvm/ViewModelContracts'), ...common('foundation/CacheConstants') };
const target = 'scp-series-2';
const requests = [];
const rcp = {
  Request: class { constructor(url) { this.url = url; } },
  createSession: () => ({ cancel() {}, close() {}, async fetch(request) {
    const slug = new URL(request.url).pathname.slice(1);
    const code = requests.length === 0 ? 503 : 200;
    requests.push([slug, code]);
    const body = code === 503 ? '暂时不可用' : '<div id="page-content"><div class="content-panel series"><li><a href="/scp-1234">SCP-1234</a> - 回声档案</li></div></div>';
    request.destination(new TextEncoder().encode(body).buffer);
    return { statusCode: code, headers: { 'content-type': 'text/html' } };
  } })
};
const sdk = new Map([
  ['anomiconbasic', basic], ['@kit.RemoteCommunicationKit', { rcp }], ['@kit.ArkData', {}], ['@kit.AbilityKit', {}],
  ['@kit.PerformanceAnalysisKit', { hilog: { warn() {} } }],
  ['@kit.ArkTS', { url: { URL: { parseURL: value => new URL(value) } }, util: { TextDecoder: {
    create: (encoding, options) => ({ decodeToString: bytes => new TextDecoder(encoding, options).decode(bytes) })
  } } }]
]);
const realLoad = Module._load;
Module._load = function (id, ...args) { return sdk.has(id) ? sdk.get(id) : realLoad.call(this, id, ...args); };
const { ScpRequestScheduler } = catalog('data/ScpRequestScheduler');
const { ScpPageFetchService } = catalog('data/ScpPageFetchService');
const { CachedArticleRepo } = catalog('data/CachedArticleRepo');
const { CatalogRepoAdapter } = catalog('data/CatalogRepoAdapter');
const { StaticCatalogHtmlParser } = catalog('data/StaticCatalogHtmlParser');
const { CatalogSearchViewModel } = catalog('presentation/viewmodel/CatalogSearchViewModel');
const { CatalogContentUseCase, CatalogSearchUseCase, SearchHistoryUseCase } = catalog('application/CatalogUseCases');
const { ALL_SERIES_ID } = catalog('domain/ScpSeriesItem');
const { SCP_CATALOG_PARSER_VERSION } = catalog('domain/StaticCatalogContracts');
Module._load = realLoad;

test('a promoted series retries HTTP 503 under continuous WEAK without starting unrelated prefetches', async t => {
  const scheduler = new ScpRequestScheduler(2, 0);
  const fetcher = new ScpPageFetchService(scheduler);
  const pages = new Map();
  const html = new CachedArticleRepo(fetcher, { get: async key => pages.get(key), registerGeneration: (_, n) => n,
    put: async item => pages.set(item.sourceUrl, item) }, scheduler);
  const stored = new Map([['scp-series', { seriesId: 'scp-series', parsedAt: Date.now(), json: JSON.stringify({
    parserVersion: SCP_CATALOG_PARSER_VERSION, ok: true, error: '', entries: [{ itemId: 'SCP-173', title: '雕像' }]
  }) }]]);
  const listeners = new Map();
  const repo = new CatalogRepoAdapter({ get: async key => stored.get(key), put: async item => {
    stored.set(item.seriesId, item); listeners.get(item.seriesId)?.(item);
  }, subscribe: (key, cb) => { listeners.set(key, cb); return () => listeners.delete(key); } }, html, StaticCatalogHtmlParser);
  const use = new CatalogSearchUseCase(new CatalogContentUseCase(repo), new SearchHistoryUseCase({ list: () => [] }));
  const vm = new CatalogSearchViewModel(use, 10, undefined, ALL_SERIES_ID);
  t.after(() => { vm.dispose(); fetcher.dispose(); });
  vm.activate();
  vm.setQuery('回声档案');
  await new Promise(setImmediate);
  assert.equal(vm.loadedSeriesCount, 1);
  assert.equal(scheduler.waiting.length, 3);
  assert.deepEqual(requests, []);

  const check = vm.checkMissingSeries();
  await vm.checkMissingSeries();
  let timer;
  // A broken retry remains queued forever. Bound the assertion and report the observed requests.
  const deadline = new Promise((_, reject) => { timer = setTimeout(() => reject(new Error(JSON.stringify(requests))), 2000); });
  try { await Promise.race([check, deadline]); } finally { clearTimeout(timer); }
  assert.deepEqual(requests, [[target, 503], [target, 200]]);
  assert.equal(vm.checkingMissingSeries, false);
  assert.equal(vm.loadedSeriesCount, 2);
  assert.deepEqual(vm.snapshot.data.entries.map(entry => entry.itemId), ['SCP-1234']);
  assert.ok(scheduler.waiting.length > 0);
});
