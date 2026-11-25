// Run after a debug phone assembleHap, with DEVECO_SDK_HOME pointing to the SDK directory.
// Execute the shipped handlers and child bindings with controlled ArkUI events, geometry and clock.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { test } from 'node:test';

const require = createRequire(import.meta.url);
const ts = require(resolve(process.env.DEVECO_SDK_HOME, '../tools/hvigor/hvigor/node_modules/typescript'));
const generated = 'products/phone/build/default/cache/default/default@CompileArkTS/esmodule/debug';
const article = 'article/src/main/ets/presentation';
const pagePath = 'phone/src/main/ets/pages/ScpArticlePage';
const rendererPath = `${article}/view/ArticleWebRenderer`;
const noop = () => {};
function compile(code) {
  return ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
}
function evaluate(code, bindings = {}, self) {
  const js = compile(`function execute() { ${code} }`);
  return Function(...Object.keys(bindings), `${js}\nreturn execute.call(this)`)
    .call(self, ...Object.values(bindings));
}
function generatedSource(path) {
  const file = `${generated}/${path}.ts`;
  return ts.createSourceFile(file, readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true);
}
function component(path, bindings) {
  const source = generatedSource(path);
  const name = path.split('/').at(-1);
  const declaration = source.statements.find(s => ts.isClassDeclaration(s) && s.name.text === name);
  const methods = declaration.members.filter(ts.isMethodDeclaration).map(m => {
    const async = m.modifiers?.some(mod => mod.kind === ts.SyntaxKind.AsyncKeyword) ? 'async ' : '';
    return async + source.text.slice(m.name.getStart(source), m.end);
  });
  return evaluate(`return new class { ${methods.join('\n')} }()`, bindings);
}
function childProps(path, childName, parent, bindings = {}) {
  const source = generatedSource(path);
  function locate(node) {
    if (ts.isNewExpression(node) && node.expression.getText(source) === childName) {
      return node.arguments[1];
    }
    return ts.forEachChild(node, locate);
  }
  return evaluate(`return (${locate(source).getText(source)})`, bindings, parent);
}
// Platform widgets record attributes and handlers set by the compiled ArkUI builders.
function widget(record = {}) {
  return new Proxy({}, { get: (_, key) => value => { record[key] = value; } });
}
const observe = fn => fn(1, true);
const touches = { Down: 0, Move: 1, Up: 2 };
function native(bindings = {}) {
  return Object.assign(component(`${article}/view/ArticleNativeRenderer`, {
    ScrollAlign: { START: 0 }, TouchType: touches, ...bindings
  }), { getUniqueId: () => 7, pendingAnchorTimer: -1, observeComponentCreation2: observe });
}

function navigationFixture(bindings = {}) {
  const callbacks = new Set();
  const geometry = new Map();
  const moves = [];
  const highlights = [];
  const observer = {
    on: (event, fn) => { assert.equal(event, 'didLayout'); callbacks.add(fn); },
    off: (event, fn) => { assert.equal(event, 'didLayout'); assert(callbacks.delete(fn)); }
  };
  const list = { getPositionToWindow: () => ({ y: 40 }), getFrameNodeById: id => geometry.get(id) ?? null };
  const view = native(bindings);
  Object.assign(view, {
    topPadding: 30, searchBarOpen: true,
    getUIContext: () => ({ getUIObserver: () => observer,
      getFrameNodeById: id => id === view.listNodeId() ? list : null }),
    scroller: { scrollToIndex: (...args) => moves.push(args), scrollBy: (...args) => moves.push(args) },
    onAnchorJump: noop, triggerAnchorHighlight: key => highlights.push(key)
  });
  return { view, callbacks, geometry, moves, highlights };
}

test('folded, inactive tab: first and 61st paragraphs scroll to their own positions', () => {
  const { view, callbacks, geometry, moves, highlights } = navigationFixture();
  const fold = { key: 'fold', expanded: false };
  const tabs = { key: 'tabs', activeTabIndex: 0 };
  Object.assign(view, {
    sectionRows: [{ blockRow: tabs }], blockRowByKey: new Map([['tabs', tabs], ['fold', { block: fold }]]),
    isExpanded: block => block.expanded, onEnsureExpanded: keys => {
      assert.deepEqual(keys, ['fold']); fold.expanded = true;
    }
  });
  for (const n of [0, 60]) {
    const key = `p${n}`;
    const location = { sectionIndex: 0, blockKey: key, expandCollapsibleKeys: ['fold'],
      tabTargets: [{ tabsBlockKey: 'tabs', tabIndex: 1 }] };
    view.jumpToSearchHit({ location, isFootnote: false });
    assert.equal(fold.expanded, true);
    assert.equal(tabs.activeTabIndex, 1);
    assert.deepEqual(moves.at(-1), [0, false, 0]);
    const [layout] = callbacks;
    layout(); // The row is materialized before the target receives geometry.
    geometry.set(view.blockNodeId(key), { getMeasuredSize: () => ({ height: 40 }),
      getPositionToWindow: () => ({ y: 170 + n * 40 }) });
    layout();
    assert.equal(callbacks.size, 0);
    assert.deepEqual(moves.at(-1), [0, 20 + n * 40]);
    assert.equal(highlights.at(-1), `block:${key}`);
  }
  view.jumpToBlockLocation({ sectionIndex: 0, blockKey: 'p60', expandCollapsibleKeys: [], tabTargets: [] });
  assert.equal(callbacks.size, 1);
  Object.assign(view, { closeSheet: noop, highlightTimer: -1 });
  view.aboutToDisappear();
  assert.equal(callbacks.size, 0);
});

test('searching a long Wikidot footnote opens and aligns the first matching passage', () => {
  const modules = new Map();
  function load(path) {
    if (!modules.has(path)) {
      const source = generatedSource(path);
      const js = ts.transpileModule(source.text, { compilerOptions: {
        module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020
      } }).outputText;
      const exports = {};
      Function('exports', 'require', js)(exports, name => load(name.split('&').at(-2)));
      modules.set(path, exports);
    }
    return modules.get(path);
  }
  const base = 'article/src/main/ets';
  const { buildArticleNavigationIndex, searchArticleDocument } = load(`${base}/domain/ArticleNavigation`);
  const { ScpNativeHtmlParser } = load(`${base}/data/ScpNativeHtmlParser`);
  const { ScpDocumentMapper } = load(`${base}/data/ScpDocumentMapper`);
  const html = '<div id="page-title">SCP-999</div><div id="page-content"><p>正文</p>' +
    '<div class="footnotes-footer"><div class="footnote-footer" id="footnote-1">' +
    '<p>普通段落</p>'.repeat(60) + '<p>后段 共同词</p><div class="collapsible-block">' +
    '<div class="collapsible-block-folded"><a class="collapsible-block-link">展开</a></div>' +
    '<div class="collapsible-block-unfolded" style="display:none"><div class="collapsible-block-content">' +
    '<p>折叠内 共同词</p></div></div></div></div></div></div>';
  const document = new ScpDocumentMapper().toDocument(ScpNativeHtmlParser.parse(html),
    'https://scp-wiki-cn.wikidot.com/scp-999', 1000);
  const note = document.footnotes[0];
  const late = note.blocks[60], fold = note.blocks[61], nested = fold.children[0];
  const sections = note.blocks.map(block => ({ sectionIndex: 1, block }));
  const { view, callbacks, geometry, moves, highlights } = navigationFixture({ searchArticleDocument,
    supportsArticleSidePanel: () => false });
  const expanded = new Set();
  Object.assign(view, { document, navigationIndex: buildArticleNavigationIndex(sections, [note], 0),
    sectionRows: [{}, { footnoteRow: note }], blockRowByKey: new Map([[fold.key, { block: fold }]]),
    isExpanded: block => expanded.has(block.key), onEnsureExpanded: keys => keys.forEach(key => expanded.add(key)) });
  for (const [query, target, y] of [['后段', late, 2570], ['共同词', late, 2570],
    ['共同词 折叠内', late, 2570], ['折叠内', nested, 2610]]) {
    view.updateSearchResults(query, true);
    assert.equal(view.searchHits.length, 1);
    assert.equal(view.searchHits[0].blockKey, target.key);
    assert.equal(view.searchHits[0].isFootnote, true);
    assert.equal(expanded.has(fold.key), target === nested);
    assert.deepEqual(moves.at(-1), [1, false, 0]);
    geometry.set(view.blockNodeId(target.key), { getMeasuredSize: () => ({ height: 40 }),
      getPositionToWindow: () => ({ y }) });
    const [layout] = callbacks;
    layout();
    assert.equal(callbacks.size, 0);
    assert.deepEqual(moves.at(-1), [0, y - 150]);
    assert.equal(highlights.at(-1), `block:${target.key}`);
  }
});

test('paragraphs, list items, table rows and cells, and tab panels expose their navigation IDs', () => {
  const renderedIds = [];
  const attributes = { set id(value) { renderedIds.push(value); } };
  const node = widget(attributes);
  const view = native({ Column: node, Row: node, Text: node, Scroll: node, If: node, ForEach: node,
    ScrollDirection: {}, BarState: {}, VerticalAlign: {}, HorizontalAlign: {}, Color: {}, FontWeight: {},
    globalThis: { Context: widget() }, AppTypography: {}, AppMotion: { fadeTransition: noop },
    pressAnimation: noop, accentPillForegroundColor: noop, accentPillBackgroundColor: noop });
  Object.assign(view, { ifElseBranchUpdateFunction: (_, draw) => draw(),
    forEachUpdateFunction: (_, rows, draw) => rows.forEach(draw), spanText: noop, blockContent: noop });
  const row = (key, children = []) => ({ key, children, block: { caption: key, level: 0 }, spans: [{}] });
  view.tabsBlock({ activeTabIndex: 0, children: [row('panel', [row('paragraph')])] }, true);
  view.listBlock(row('list', [row('item')]), true);
  view.tableGrid(row('table', [row('row', [row('cell')])]), true, 0);
  assert.deepEqual(renderedIds, ['panel', 'paragraph', 'item', 'row', 'cell'].map(key => view.blockNodeId(key)));
});

test('footer uses pull-up guidance without an explicit completion button', () => {
  const buttons = [];
  const ButtonProxy = new Proxy({}, {
    get: (_, key) => value => {
      if (key === 'createWithLabel') {
        buttons.push(value);
      }
    }
  });
  const view = native({ Column: widget(), If: widget(), Row: widget(), Stack: widget(), SymbolGlyph: widget(),
    Text: widget(), Button: ButtonProxy, Alignment: {}, HorizontalAlign: {}, VerticalAlign: {}, AppTypography: {} });
  let activations = 0;
  let hapticCount = 0;
  let atBottom = true;
  Object.assign(view, {
    ifElseBranchUpdateFunction: (_, action) => action(),
    document: { pageVersion: '' },
    bottomPullProgress: 0,
    bottomPullReady: false,
    bottomPullTracking: false,
    bottomPullAnchorY: 0,
    bottomPullLastY: 0,
    bottomPullTriggerVp: 72,
    bottomPullDeadZoneVp: 4,
    completed: false,
    scroller: { isAtEnd: () => atBottom },
    isScrollerAtBottom: () => atBottom,
    cancelBlockAlignment: noop,
    clampValue: (val, min, max) => Math.max(min, Math.min(max, val)),
    bottomPullBarWidth: () => 0,
    bottomPullBarFillColor: noop,
    bottomPullPrimaryIcon: noop,
    bottomPullPrimaryWeight: noop,
    bottomPullPrimaryText: noop,
    bottomPullPrimaryColor: noop,
    onBottomPullHaptic: () => { hapticCount++; },
    onToggleCompleted: () => { activations++; view.completed = !view.completed; }
  });
  view.licenseFooter();
  assert.equal(buttons.length, 0);

  // Slow 1vp-per-frame pull-up with transient isAtEnd() flicker mid-pull must remain monotonic.
  view.handleListTouch({ type: touches.Down, touches: [{ windowY: 500 }], changedTouches: [] });
  let previousProgress = 0;
  for (let y = 499; y >= 420; y--) {
    if (y === 488) {
      atBottom = false;
    }
    view.handleListTouch({ type: touches.Move, touches: [{ windowY: y }], changedTouches: [] });
    assert.ok(view.bottomPullProgress >= previousProgress, `progress dropped at y=${y}`);
    previousProgress = view.bottomPullProgress;
  }
  assert.equal(view.bottomPullReady, true);
  assert.equal(view.bottomPullProgress, 1);
  assert.equal(hapticCount, 1);
  view.handleListTouch({ type: touches.Up, touches: [], changedTouches: [{ windowY: 420 }] });
  assert.equal(activations, 1);
  assert.equal(view.completed, true);
});

function webFixture() {
  const sourceUrl = 'https://scp-wiki-cn.wikidot.com/scp-cn-2000';
  const events = {};
  const opened = [];
  const input = [];
  const history = [];
  const platformUrl = { URL: { parseURL: (value, base) => new URL(value, base) } };
  const policySource = readFileSync('common/anomiconbasic/src/main/ets/platform/ExternalUrlPolicy.ets', 'utf8');
  const ExternalUrlPolicy = evaluate(policySource.slice(policySource.indexOf('export class')).replace('export class', 'class') +
    '\nreturn ExternalUrlPolicy;', { url: platformUrl });
  const page = component(pagePath, { supportsSplitNavigation: () => false, windowWidthVp: () => 400, ExternalUrlPolicy });
  Object.assign(page, { sourceUrl, webModeUrl: sourceUrl, currentWebUrl: sourceUrl, webModeActive: true,
    acceptsProgressEvents: true, lastKnownReadingOffset: 30, itemId: 'scp-cn-2000', settings: {},
    viewModel: { noteInteraction: offset => input.push(offset) }, isCurrentFavorite: () => false,
    canOpenArchive3D: () => false, offlineMenuLabel: noop, offlineMenuIcon: noop,
    getUIContext: () => ({ getHostContext: () => ({ openLink: url => opened.push(url) }) }) });
  const renderer = childProps(pagePath, 'ArticleWebRenderer', page, { pageContentTop: () => 0, ARTICLE_READING_STATUS_HEIGHT: 0 });
  renderer.retryEpoch = 0;
  const props = childProps(rendererPath, 'ArticleWebSurface', renderer);
  let cooldown;
  const surface = Object.assign(component(`${article}/adapter/ArticleWebSurface`, {
    Web: widget(events), RenderMode: {}, MixedMode: {}, TouchType: touches, KeyType: { Down: 0 }, url: platformUrl,
    WIKI_HOST: new URL(sourceUrl).hostname, WIKIDOT_CLEANUP_SCRIPT: '',
    setTimeout: fn => { cooldown = fn; return 1; }, clearTimeout: noop
  }), props, { observeComponentCreation2: observe, controllerAttached: true, inputCooldown: -1,
    controller: { accessBackward: () => history.length > 1, backward: () => {
      history.pop(); events.onNavigationEntryCommitted({ isMainFrame: true, url: history.at(-1) });
    } } });
  surface.aboutToAppear();
  surface.initialRender();
  return { page, surface, events, opened, history, input, releaseCooldown: () => cooldown() };
}

test('web input renews the 90-second idle window; load events alone leave it idle', () => {
  const policy = readFileSync('features/library/src/main/ets/domain/ReadingActivityPolicy.ets', 'utf8');
  const end = evaluate(policy.replaceAll('export function', 'function') + '\nreturn readingActivityCreditedEndUptime;');
  const { page, events, input, releaseCooldown } = webFixture();
  let lastInput = 0;
  let now = 0;
  page.viewModel.noteInteraction = offset => { assert.equal(offset, 30); lastInput = now; input.push(now); };
  for (now = 0; now <= 180000; now += 30000) {
    events.onTouch({ type: touches.Move });
    events.onAxisEvent({}); // Coalesced with the touch from the same frame.
    releaseCooldown();
  }
  assert.equal(input.length, 7);
  assert.equal(end(180000, lastInput, 90000), 180000);
  events.onProgressChange({ newProgress: 100 });
  assert.equal(end(360000, lastInput, 90000), 270000);
  page.acceptsProgressEvents = false;
  events.onKeyEvent({ type: 0 });
  assert.equal(input.length, 7);
  const idle = webFixture();
  idle.events.onProgressChange({ newProgress: 100 });
  assert.equal(idle.input.length, 0);
  assert.equal(end(180000, 0, 90000), 90000);
});

test('iteration, fragment and browser back hand off the committed main document', async () => {
  const { page, surface, events, opened, history } = webFixture();
  const base = page.sourceUrl;
  const iteration = `${base}/offset/2`;
  const fragment = `${iteration}#notes`;
  const menu = page.articleMenuItems().find(item => item.content.label === '在浏览器中打开').content;
  assert.equal(surface.handleMainFrameNavigation(iteration), false);
  for (const url of [base, iteration, fragment]) {
    history.push(url);
    events.onNavigationEntryCommitted({ isMainFrame: true, url });
    events.onNavigationEntryCommitted({ isMainFrame: false, url: 'https://example.org/frame' });
    await menu.action();
    assert.equal(opened.at(-1), url);
    assert.equal(page.webModeUrl, base);
  }
  surface.backEpoch = 1;
  surface.onBackRequested();
  await menu.action();
  assert.equal(opened.at(-1), iteration);
});
