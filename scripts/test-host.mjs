#!/usr/bin/env node
// Run from the project root after ohpm install --all.
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';

const modules = new Map();
for (const group of ['common', 'features', 'products']) {
  for (const entry of readdirSync(group, { withFileTypes: true })) {
    const dir = join(group, entry.name);
    const tests = join(dir, 'src/test');
    if (entry.isDirectory() && existsSync(tests) &&
        readdirSync(tests).some(name => name.endsWith('.test.ets') && name !== 'List.test.ets')) {
      modules.set(entry.name, dir);
    }
  }
}

const selected = process.argv.length > 2 ? process.argv.slice(2) : [...modules.keys()];
if (selected.length === 0 || selected.some(name => !modules.has(name))) {
  console.error(`请选择有主机用例的模块：${[...modules.keys()].join(', ')}`);
  process.exit(2);
}

for (const name of selected) {
  const report = join(modules.get(name), '.test/default/intermediates/test/coverage_data/test_result.txt');
  // Require this invocation to produce its own report, even after a previous green run.
  rmSync(report, { force: true });
  const run = spawnSync('hvigorw', [
    '--no-daemon', '--mode', 'module', '-p', `module=${name}@default`, '-p', 'product=default', 'test'
  ], { stdio: 'inherit' });
  if (run.error) throw run.error;
  if (run.status !== 0) process.exit(run.status ?? 1);

  const lines = readFileSync(report, 'utf8').trimEnd().split(/\r?\n/);
  let test = '';
  let passed = 0;
  let failed = false;
  for (const line of lines) {
    if (line.startsWith('test=')) test = line.slice('test='.length);
    if (!line.startsWith('result=')) continue;
    if (line === 'result=Success') {
      passed++;
    } else if (line !== 'result=Ignore') {
      console.error(`${name} · ${test} · ${line}`);
      failed = true;
    }
  }
  const summary = lines.at(-1);
  console.log(`${name} · ${summary}`);
  const counts = /^Tests run: (\d+), Failure: (\d+), Error: (\d+), Pass: (\d+), Ignore: (\d+)/.exec(summary);
  if (failed || !counts || passed === 0 || Number(counts[2]) || Number(counts[3]) || Number(counts[4]) !== passed) {
    console.error(`主机测试未通过：${report}`);
    process.exit(1);
  }
}
