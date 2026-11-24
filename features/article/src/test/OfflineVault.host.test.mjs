// Node 24+: node --test features/article/src/test/OfflineVault.host.test.mjs
// Exercise the production vault against host files and SQLite, adapting only platform APIs.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { randomUUID } from 'node:crypto';
import { stripTypeScriptTypes } from 'node:module';
import { DatabaseSync } from 'node:sqlite';

function loadArkTs(path, names, imports = {}) {
  const source = fs.readFileSync(new URL(`../main/ets/${path}.ets`, import.meta.url), 'utf8');
  const script = stripTypeScriptTypes(source.replace(/^import [\s\S]*?;\n/gm, '').replace(/^export /gm, ''),
    { mode: 'transform' });
  return Function(...Object.keys(imports), `${script}\nreturn {${names}};`)(...Object.values(imports));
}

const { ScpBlockType } = loadArkTs('domain/ScpDocument', ['ScpBlockType']);
const domain = loadArkTs('domain/ArticleOfflineContracts', [
  'ArticleOfflineSnapshot', 'ArticleOfflineSummary', 'collectArticleImageUrls', 'evaluateOfflineReadiness',
  'normalizeOfflineImageUrl', 'requiresNetworkForInteractiveDocument'
], { ScpBlockType });

const fileIo = {
  OpenMode: { CREATE: fs.constants.O_CREAT, WRITE_ONLY: fs.constants.O_WRONLY,
    READ_ONLY: fs.constants.O_RDONLY, TRUNC: fs.constants.O_TRUNC, NOFOLLOW: fs.constants.O_NOFOLLOW },
  open: (path, mode) => ({ fd: fs.openSync(path, mode) }), close: file => fs.closeSync(file.fd),
  copyFile: (src, dst) => fs.writeFileSync(dst, fs.readFileSync(src)),
  read: (fd, buffer) => fs.readSync(fd, new Uint8Array(buffer)),
  write: (fd, buffer) => fs.writeSync(fd, new Uint8Array(buffer)), fsync: fs.fsyncSync,
  access: fs.existsSync, stat: fs.statSync, lstat: fs.lstatSync, rename: fs.renameSync,
  listFile: fs.readdirSync, mkdir: fs.mkdirSync, rmdir: fs.rmdirSync, unlink: fs.unlinkSync
};

class AsyncLock {
  tail = Promise.resolve();
  lockAsync(fn) {
    const result = this.tail.then(fn);
    this.tail = result.catch(() => {});
    return result;
  }
}

class Predicates {
  equalTo(key, value) { this.key = key; this.value = value; }
  limitAs() {}
}

function arkStore(db) {
  return {
    executeSql: sql => db.exec(sql),
    insert(table, values) {
      const keys = Object.keys(values);
      const args = keys.map(() => '?');
      return db.prepare(`INSERT OR REPLACE INTO ${table} (${keys}) VALUES (${args})`)
        .run(...Object.values(values)).lastInsertRowid;
    },
    query(predicate, columns) {
      const row = db.prepare(`SELECT ${columns} FROM offline_articles WHERE ${predicate.key}=?`).get(predicate.value);
      return { goToFirstRow: () => !!row, getColumnIndex: key => columns.indexOf(key),
        getLong: i => row[columns[i]], getString: i => row[columns[i]], close() {} };
    }
  };
}

const { RdbOfflineArticleStore } = loadArkTs('data/RdbOfflineArticleStore', ['RdbOfflineArticleStore'], {
  ...domain, fs: fileIo, fileUri: { getUriFromPath: path => pathToFileURL(path).href },
  util: { generateRandomUUID: () => randomUUID(), TextEncoder: { create: () => ({ encodeInto: str => new TextEncoder().encode(str) }) },
    TextDecoder: { create: () => ({ decodeToString: bytes => new TextDecoder().decode(bytes) }) } },
  ArkTSUtils: { locks: { AsyncLock, AsyncLockMode: { EXCLUSIVE: 1 } } },
  relationalStore: { RdbPredicates: Predicates, getRdbStore: context => arkStore(context.db),
    SecurityLevel: { S1: 1 }, ConflictResolution: { ON_CONFLICT_REPLACE: 1 } },
  LibraryContentKind: { SCP: 'scp' }, ANOMICON_DATABASE_NAME: 'vault.sqlite'
});

const content = { id: 'scp-2521', kind: 'scp', key: 'main:scp-2521', title: 'SCP-2521' };
const sourceUrl = 'https://scp-wiki-cn.wikidot.com/scp-2521';
const imageUrl = name => `${sourceUrl}/${name}.png`;
const parser = { currentSchemaVersion: () => 1, parse: JSON.parse };
function document(revision, imageNames) {
  return { title: revision, sourceUrl, itemId: content.id, images: imageNames.map(name => ({ source: imageUrl(name) })),
    blocks: [], footnotes: [], creditBlocks: [], parserWarnings: [] };
}

function createScenario(t) {
  const tempDir = fileURLToPath(new URL('../../.test/', import.meta.url));
  fs.mkdirSync(tempDir, { recursive: true });
  const root = fs.mkdtempSync(join(tempDir, 'offline-vault-'));
  let db;
  const requests = [];
  const missing = new Set();
  const reopen = () => {
    db?.close();
    db = new DatabaseSync(join(root, 'vault.sqlite'));
    return new RdbOfflineArticleStore({ getApplicationContext: () => ({ filesDir: root }), db }, parser, {
      async fetchToLocalFile(url) {
        requests.push(url);
        if (missing.has(url)) return '';
        const path = join(root, basename(url));
        fs.writeFileSync(path, `image bytes: ${url}`);
        return path;
      }
    });
  };
  t.after(() => {
    db?.close();
    assert.equal(dirname(root), fs.realpathSync(tempDir));
    assert.ok(basename(root).startsWith('offline-vault-'));
    fs.rmSync(root, { recursive: true });
  });
  return { reopen, get db() { return db; }, requests, missing };
}

function assertImage(record, name) {
  const url = imageUrl(name);
  const path = fileURLToPath(record.snapshot.localImageUris.get(url));
  assert.equal(fs.readFileSync(path, 'utf8'), `image bytes: ${url}`);
}

for (const legacy of [true, false]) {
  test(`last SQLite write fails, cold reopen keeps complete ${legacy ? 'legacy' : 'versioned'} archive`, async t => {
    const scenario = createScenario(t);
    let store = scenario.reopen();
    const oldBody = document('v1', ['a']);
    const newBody = document('v2', ['b']);
    await store.save(content, oldBody, JSON.stringify(oldBody));
    const row = () => scenario.db.prepare('SELECT * FROM offline_articles').get();
    const versionDir = dirname(row().document_path);
    const articleDir = dirname(versionDir);
    if (legacy) {
      // Pre-upgrade rows address document.json and images/ directly under the article directory.
      fs.copyFileSync(row().document_path, join(articleDir, 'document.json'));
      fs.cpSync(join(versionDir, 'images'), join(articleDir, 'images'), { recursive: true });
      scenario.db.prepare('UPDATE offline_articles SET document_path=?').run(join(articleDir, 'document.json'));
    }
    const before = row();
    scenario.db.exec("CREATE TRIGGER fail_publish BEFORE INSERT ON offline_articles BEGIN SELECT RAISE(ABORT,'last write failed'); END");
    await assert.rejects(store.save(content, newBody, JSON.stringify(newBody)), /last write failed/);
    store = scenario.reopen();
    assert.deepEqual(row(), before);
    const saved = await store.loadDocument(content);
    assert.deepEqual(saved.document, oldBody);
    assert.equal(saved.snapshot.savedImages, 1);
    assert.equal(saved.snapshot.missingImages, 0);
    assertImage(saved, 'a');

    scenario.db.exec('DROP TRIGGER fail_publish');
    await store.save(content, newBody, JSON.stringify(newBody));
    store = scenario.reopen();
    const updated = await store.loadDocument(content);
    assert.deepEqual(updated.document, newBody);
    assertImage(updated, 'b');
    assert.equal(fs.existsSync(before.document_path), false);
    assert.deepEqual(fs.readdirSync(articleDir), [basename(dirname(row().document_path))]);
  });
}

test('incomplete explicit update preserves v1 until a complete retry publishes v2', async t => {
  const scenario = createScenario(t);
  let store = scenario.reopen();
  const oldBody = document('v1', ['a']);
  const newBody = document('v2', ['b']);
  await store.save(content, oldBody, JSON.stringify(oldBody));
  scenario.missing.add(imageUrl('b'));
  await assert.rejects(store.save(content, newBody, JSON.stringify(newBody), undefined, true), /仍缺 1 张图/);
  store = scenario.reopen();
  const old = await store.loadDocument(content);
  assert.deepEqual(old.document, oldBody);
  assertImage(old, 'a');
  scenario.missing.clear();
  await store.save(content, newBody, JSON.stringify(newBody), undefined, true);
  const current = await scenario.reopen().loadDocument(content);
  assert.deepEqual(current.document, newBody);
  assertImage(current, 'b');
});

test('repair copies the saved image and downloads only the missing one', async t => {
  const scenario = createScenario(t);
  const store = scenario.reopen();
  const body = document('v1', ['a', 'b']);
  scenario.missing.add(imageUrl('b'));
  const first = await store.save(content, body, JSON.stringify(body));
  assert.equal(first.missingImages, 1);
  scenario.missing.clear();
  scenario.requests.length = 0;
  await store.save(content, body, JSON.stringify(body));
  const saved = await scenario.reopen().loadDocument(content);
  assert.equal(saved.snapshot.missingImages, 0);
  assert.deepEqual(scenario.requests, [imageUrl('b')]);
  assertImage(saved, 'a');
  assertImage(saved, 'b');
});
