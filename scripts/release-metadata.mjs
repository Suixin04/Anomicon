import { execFileSync } from 'node:child_process';
import { appendFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs';

const git = (...args) => execFileSync('git', args, { encoding: 'utf8' }).trim();
const config = readFileSync('AppScope/app.json5', 'utf8');
const version = config.match(/^\s*"versionName"\s*:\s*"((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))"\s*,?\s*$/m)?.[1];
const code = config.match(/^\s*"versionCode"\s*:\s*([1-9]\d*)\s*,?\s*$/m)?.[1];
if (!version || !code || !Number.isSafeInteger(Number(code))) {
  throw new Error('AppScope/app.json5 中的 versionName 或 versionCode 格式无效');
}

const tag = `v${version}(${code})`;
const title = `Anomicon v${version}`;
const asset = `Anomicon-v${version}-${code}-unsigned.hap`;
const sha = git('rev-parse', 'HEAD');
git('check-ref-format', `refs/tags/${tag}`);

const parseTags = (names) => names.split('\n').flatMap(name => {
  const match = name.match(/^v(\d+\.\d+\.\d+)\(([1-9]\d*)\)$/);
  return match && Number.isSafeInteger(Number(match[2])) ?
    [{ name, version: match[1], code: Number(match[2]) }] : [];
});
const tags = parseTags(git('tag', '--list'));
const latest = [...tags].sort((a, b) => b.code - a.code)[0];
const previous = parseTags(git('tag', '--merged', sha)).filter(item => item.name !== tag)
  .sort((a, b) => b.code - a.code)[0];
const compareVersion = (left, right) => {
  const a = left.split('.').map(BigInt);
  const b = right.split('.').map(BigInt);
  for (let part = 0; part < 3; part++) {
    if (a[part] !== b[part]) return a[part] > b[part] ? 1 : -1;
  }
  return 0;
};
if (!tags.some(item => item.name === tag)) {
  if (latest && latest.code >= Number(code)) {
    throw new Error(`versionCode 必须高于已有发布标签 ${latest.name}`);
  }
  const nonIncreasing = tags.find(item => compareVersion(version, item.version) <= 0);
  if (nonIncreasing) {
    throw new Error(`versionName 必须按 SemVer 高于已有发布标签 ${nonIncreasing.name}`);
  }
}

const notesFile = `.github/release-notes/${tag}.md`;
const range = previous ? `${previous.name}..${sha}` : sha;
const subjects = git('log', '--no-merges', '--format=%s', range).split('\n').filter(Boolean);
const repository = process.env.GITHUB_REPOSITORY;
const encodeRef = (ref) => encodeURIComponent(ref).replace(/\(/g, '%28').replace(/\)/g, '%29');
const compare = previous && repository ?
  `\n\n[完整变更](https://github.com/${repository}/compare/${encodeRef(previous.name)}...${encodeRef(tag)})` : '';
const groups = new Map([['新增与优化', []], ['问题修复', []], ['其他变更', []]]);
for (const subject of new Set(subjects)) {
  const match = subject.match(/^(feat|perf|fix)(?:\([^)]*\))?!?:\s*(.+)$/i);
  const type = match?.[1].toLowerCase();
  const group = type === 'fix' ? '问题修复' : type ? '新增与优化' : '其他变更';
  const lines = groups.get(group);
  if (lines.length < 5) lines.push(`- ${match?.[2] ?? subject}`);
}
const fallback = [...groups].filter(([, lines]) => lines.length > 0)
  .map(([name, lines]) => [`## ${name}`, '', ...lines].join('\n')).join('\n\n');
const notes = (existsSync(notesFile) ? readFileSync(notesFile, 'utf8').trim() : '') || fallback;
writeFileSync(process.argv[2] ?? 'release-notes.md', `${notes}${compare}\n`);
if (process.env.GITHUB_OUTPUT) {
  appendFileSync(process.env.GITHUB_OUTPUT, `tag=${tag}\ntitle=${title}\nasset=${asset}\nsha=${sha}\n`);
} else {
  console.log(`${tag}\n${title}\n${sha}`);
}
