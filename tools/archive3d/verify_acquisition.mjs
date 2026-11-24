// Run after building phone@default in debug mode with the API 26 SDK.
// Exercise the compiled route and button callbacks without a native 3D scene or request.agent.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(import.meta.url);
const ts = require(path.join(process.env.DEVECO_SDK_HOME, 'default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'));
const cache = 'products/phone/build/default/cache/default/default@CompileArkTS/esmodule/debug';
const modules = new Map();
const noop = () => {};
function load(modulePath) {
  const text = readFileSync(`${cache}/${modulePath}.ts`, 'utf8');
  const code = ts.transpileModule(text, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, experimentalDecorators: true
  } }).outputText;
  const out = {};
  new Function('exports', 'require', code)(out, spec => modules.get(path.basename(spec.split('&&&').at(-1).split('&')[0])) ?? {});
  modules.set(path.basename(modulePath), out);
  return out;
}
const archive = suffix => load(`archive3d/src/main/ets/${suffix}`);
const phone = suffix => load(`phone/src/main/ets/${suffix}`);
const tick = () => new Promise(resolve => setImmediate(resolve));
const labels = [], buttons = new Map(), callbacks = new Map();
let currentButton, cardClick, builtPage;
const widget = methods => new Proxy(methods, { get: (obj, key) => obj[key] ?? noop });
const destination = widget(Object.fromEntries(['onReady', 'onActive', 'onShown', 'onHidden'].map(key =>
  [key, fn => callbacks.set(key, fn)])));
class View {
  static create(page) { builtPage = page; }
  initParam(name, value) { this[name] = value; }
  finalizeConstruction() {}
  observeComponentCreation2(fn) { fn(0, true); }
  ifElseBranchUpdateFunction(_id, fn) { fn(); }
}
Object.assign(globalThis, { ViewPU: View, ViewV2: View, Context: { animation: noop }, Scroller: class {}, Local: noop, Param: noop, Computed: noop,
  Monitor: () => noop, Require: noop, Event: noop, Once: noop, Trace: noop, ObservedV2: noop,
  Button: widget({ createWithLabel(label) { currentButton = label; }, onClick(fn) { buttons.set(currentButton, fn); } }),
  Text: widget({ create(label) { labels.push(label); } }), Column: widget({ onClick(fn) { cardClick = fn; } }),
  Row: widget({}), If: widget({}), SymbolGlyph: widget({}), LoadingProgress: widget({}) });
for (const name of ['FontWeight', 'TextAlign', 'FlexAlign', 'VerticalAlign', 'HorizontalAlign', 'TextOverflow',
  'LayoutSafeAreaType', 'LayoutSafeAreaEdge', 'HitTestMode', 'ModelType']) globalThis[name] = {};
modules.set('@hms:hds.hdsBaseComponent', { HdsNavDestination: destination, HdsNavDestinationTitleMode: {}, HideMode: {} });
modules.set('@ohos:arkui.uiMaterial', { default: { ImmersiveMaterial: class {}, ImmersiveStyle: {} } });
modules.set('@ohos:arkui.UIContext', { FrameCallback: class {} });
modules.set('@hms:fast.schedulingOptimization', { default: { SceneType: {}, DurationType: {} } });
modules.set('FastPerformanceHints', { FastPerformanceHintScope: class { begin() {} end() {} } });
modules.set('AppMotion', { DestinationMotionState: class {}, NavigationTransitionRegistry: { register: noop, unregister: noop } });
modules.set('AppTypography', { AppTypography: {} });
modules.set('ResponsiveLayoutPolicy', { supportsSplitNavigation: () => false });
modules.set('VisualTokens', widget({}));
modules.set('PressFeedback', { pressAnimation: noop });
const stack = { paths: [{name:'article'}], size() { return this.paths.length; },
  async pushDestination(item) { this.paths.push(item); }, pop() { this.paths.pop(); } };
const nav = load('anomiconbasic/src/main/ets/ui/NavigationStyles');
modules.set('NavigationStyles', { ...nav, createAppTitleBarStyle: noop, windowWidthVp: () => 400 });

const assets = archive('domain/Scp3DModelAsset');
const { ArchiveModelDescriptor, ArchiveSceneSource } = archive('domain/ArchiveModelDescriptor');
archive('domain/ArchiveModelInstall');
archive('data/ArchiveModelFileStore');
const { BackgroundDownloadState } = load('anomiconbasic/src/main/ets/platform/BackgroundDownloadContracts');
const { SandboxArchiveModelPackageRepository } = archive('data/SandboxArchiveModelPackageRepository');
const { ArchiveModelUseCase } = archive('application/ArchiveModelUseCase');
archive('composition/Archive3DFeatureFactory');
const { createLibraryContentRef, LibraryContentKind } = load('library/src/main/ets/domain/LibraryContentRef');
phone('navigation/AppRoutes');
phone('navigation/RouteParamAdapters');
phone('navigation/AppNavigationCoordinator');
modules.set('SettingsModels', { ReadingSettingsRange: {} });
modules.set('ArticleScrollRestore', { ArticleScrollRestore: class {} });
phone('pages/ScpArticlePage');
phone('pages/Scp3DArchiveGalleryPage');
const renderSources = [];
modules.set('Archive3DSceneLoader', { async loadArchive3DScene(_asset, source) { renderSources.push(source); return { scene: {} }; } });
phone('pages/Scp3DArchivePage');
let useCase;
const app = { archive3DModels: () => useCase, settings: () => ({}), createArticleViewModel: () => ({ content }),
  createHapticFeedback: () => ({ playSelection: noop }), createImagePreviewActions: noop,
  researchProfile: noop, storySeries: noop, networkBoost: noop };
modules.set('AppContainer', { AppContainer: { getInstance: () => app } });
const routes = phone('pages/routes/RouteAdapters');
const { routerMap } = JSON.parse(readFileSync('products/phone/src/main/resources/base/profile/route_map.json', 'utf8'));
function buildPage(name) {
  const { buildFunction } = routerMap.find(route => route.name === name);
  routes[buildFunction].call(new View());
  return builtPage;
}

const row = assets.SCP_3D_ASSET_MANIFEST.find(row => row.contentId === 'scp-131');
const model = ArchiveModelDescriptor.fromAsset(assets.resolveScp3DModelAsset(row.contentId));
let record, installed, createCount = 0, resumeCount = 0, state, bytes = 0, listener;
const task = { id: '42', token: '', async inspect() { return { id: this.id, state, processedBytes: bytes, totalBytes: model.byteLength, reason: '' }; },
  async emit(value) { state = value; listener?.(await this.inspect()); },
  async start() { await this.emit(BackgroundDownloadState.RUNNING); },
  async resume() { resumeCount++; await this.emit(BackgroundDownloadState.RUNNING); },
  subscribe(fn) { listener = fn; return () => { listener = undefined; }; }, dispose: noop };
const downloads = { async create(req) { assert.equal(req.url, row.downloadUrl); createCount++; task.token = req.token; return task; },
  async reconnect(id, token) { assert.deepEqual([id, token], [task.id, task.token]); return task; } };
const files = { async locate(m, verify) { assert.equal(verify, true); return m.assetId === model.assetId ? installed : undefined; },
  async prepareStaging() { return '/data/storage/el2/base/files/archive3d/v1/staging/test.part'; },
  async readPending(m) { return m.assetId === model.assetId ? record : undefined; }, async writePending(_m, r) { record = r; },
  async verifyAndPublish(m, stage) { assert.equal(stage, record.stagingPath); return installed = ArchiveSceneSource.sandbox(m, `/data/storage/el2/base/files/archive3d/v1/objects/${m.sha256.slice(0,2)}/${m.sha256}.glb`); },
  async removePending() { record = undefined; }, async removeStaging() {} };
function restart() { useCase = new ArchiveModelUseCase(new SandboxArchiveModelPackageRepository('', downloads, { generate: () => 'stable-token' }, files)); }
function openGallery(param) {
  const gallery = buildPage('archive3dGallery');
  gallery.aboutToAppear();
  gallery.initialRender();
  callbacks.get('onReady')({ pathStack: stack, pathInfo: { param } });
  return gallery;
}
function draw(gallery) { buttons.clear(); labels.length = 0; gallery.archiveCard(row); }
restart();
const content = createLibraryContentRef(LibraryContentKind.SCP, row.contentId, row.contentId.toUpperCase());
const article = buildPage('article');
Object.assign(article, { contentKind: content.kind, itemId: content.id, routeResolved: true, pageStack: stack });
article.articleMenuItems().find(item => item.content.label === '三维档案').content.action();
await tick();
assert.equal(stack.paths.at(-1).name, 'archive3d');
const viewer = buildPage(stack.paths.at(-1).name);
viewer.requestRender = noop;
viewer.initialRender();
const lifecycle = new Map(callbacks);
lifecycle.get('onReady')({ pathStack: stack, pathInfo: stack.paths.at(-1) });
lifecycle.get('onActive')(); lifecycle.get('onShown')();
await tick();
viewer.errorOverlay();
assert.equal(renderSources.length, 0);
buttons.get('获取此模型')();
await tick();
assert.deepEqual(stack.paths.at(-1), { name: 'archive3dGallery', param: {assetId: row.assetId} });
lifecycle.get('onHidden')();
let gallery = openGallery(stack.paths.at(-1).param);
assert.deepEqual(gallery.visibleEntries(), [row]);
await tick(); draw(gallery); buttons.get('下载')(); await tick();
assert.equal(createCount, 1);
bytes = 4096;
await task.emit(BackgroundDownloadState.PAUSED);
const identity = [record.taskId, record.token, record.stagingPath];
for (const rebuild of [false, true]) {
  gallery.aboutToDisappear();
  if (rebuild) restart();
  gallery = openGallery(stack.paths.at(-1).param);
  await tick(); draw(gallery);
  assert.ok(labels.includes('已暂停')); assert.ok(buttons.has('继续下载'));
  buttons.get('继续下载')(); await tick(); draw(gallery);
  assert.ok(labels.includes('下载中')); assert.equal(buttons.has('继续下载'), false);
  assert.equal((await useCase.snapshot(model)).processedBytes, 4096);
  assert.deepEqual([record.taskId, record.token, record.stagingPath], identity);
  assert.equal(createCount, 1);
  if (!rebuild) await task.emit(BackgroundDownloadState.PAUSED);
}
await task.emit(BackgroundDownloadState.COMPLETED); await tick(); draw(gallery);
assert.ok(labels.includes('已下载')); assert.ok(labels.includes('查看模型'));
cardClick(); lifecycle.get('onActive')(); lifecycle.get('onShown')(); await tick();
assert.deepEqual(stack.paths.map(p => p.name), ['article', 'archive3d']);
assert.deepEqual(renderSources, [installed]); assert.equal(viewer.sceneReady, true);
assert.equal(resumeCount, 2);
gallery.aboutToDisappear();
assert.equal(openGallery(undefined).visibleEntries().length, assets.SCP_3D_ASSET_MANIFEST.length);
console.log('PASS SCP-131 正文 → 获取此模型 → 专属卡片 → 查看模型 → 原查看器');
console.log('PASS 重开档案馆与重建仓库均显示已暂停并续传。任务 42，保留 4096 字节，创建 1 次、继续 2 次。');
