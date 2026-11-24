import {
  CatalogEntry,
  CatalogTaleEntry,
  normalizeCatalogItemId
} from './CatalogContracts';
import { isCnScpItemId } from './ScpSeriesItem';

export enum CatalogSearchTargetKind {
  SCP = 'scp',
  TALE = 'tale'
}

export class CatalogDirectTarget {
  readonly kind: CatalogSearchTargetKind;
  readonly itemId: string;
  readonly title: string;
  readonly subtitle: string;
  readonly matched: boolean;
  readonly anchor?: string;

  constructor(
    kind: CatalogSearchTargetKind,
    itemId: string,
    title: string,
    subtitle: string,
    anchor?: string,
    matched: boolean = false
  ) {
    this.kind = kind;
    this.itemId = itemId;
    this.title = title;
    this.subtitle = subtitle;
    this.anchor = anchor;
    this.matched = matched;
  }
}

const ALLOWED_WIKI_HOSTS: string[] = [
  'scp-wiki-cn.wikidot.com',
  'www.scp-wiki-cn.wikidot.com',
  'scp-wiki.wikidot.com',
  'www.scp-wiki.wikidot.com'
];

const DIRECT_SCP_SLUG_REGEX: RegExp =
  /^scp-(?:(?:[a-z]{2,4}-)?\d+|[a-z0-9]*\d+[a-z0-9]*)(?:-[a-z0-9]+)*$/i;

function safeDecodeFragment(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed.length === 0) {
    return '';
  }
  try {
    return decodeURIComponent(trimmed);
  } catch (_error) {
    return trimmed;
  }
}

function padScpDigits(digits: string): string {
  if (digits.length >= 3) {
    return digits;
  }
  return digits.padStart(3, '0');
}

function resolveWikiUrlTarget(trimmed: string): CatalogDirectTarget | undefined {
  let remainder: string = '';
  const lower = trimmed.toLowerCase();
  if (lower.startsWith('https://')) {
    remainder = trimmed.substring(8);
  } else if (lower.startsWith('http://')) {
    remainder = trimmed.substring(7);
  } else {
    let matchedBareHost = false;
    for (let index = 0; index < ALLOWED_WIKI_HOSTS.length; index++) {
      const prefix = `${ALLOWED_WIKI_HOSTS[index]}/`;
      if (lower.startsWith(prefix)) {
        remainder = trimmed;
        matchedBareHost = true;
        break;
      }
    }
    if (!matchedBareHost) {
      return undefined;
    }
  }

  let endOfHost = remainder.length;
  const slashIndex = remainder.indexOf('/');
  const queryIndex = remainder.indexOf('?');
  const hashIndex = remainder.indexOf('#');
  if (slashIndex >= 0 && slashIndex < endOfHost) {
    endOfHost = slashIndex;
  }
  if (queryIndex >= 0 && queryIndex < endOfHost) {
    endOfHost = queryIndex;
  }
  if (hashIndex >= 0 && hashIndex < endOfHost) {
    endOfHost = hashIndex;
  }
  const host = remainder.substring(0, endOfHost).toLowerCase();
  if (!ALLOWED_WIKI_HOSTS.includes(host)) {
    return undefined;
  }

  let pathAndMore = remainder.substring(endOfHost);
  let anchor: string | undefined = undefined;
  const fragmentIndex = pathAndMore.indexOf('#');
  if (fragmentIndex >= 0) {
    const decoded = safeDecodeFragment(pathAndMore.substring(fragmentIndex + 1));
    if (decoded.length > 0) {
      anchor = decoded;
    }
    pathAndMore = pathAndMore.substring(0, fragmentIndex);
  }
  const paramIndex = pathAndMore.indexOf('?');
  if (paramIndex >= 0) {
    pathAndMore = pathAndMore.substring(0, paramIndex);
  }
  const slug = pathAndMore.replace(/^\/+|\/+$/g, '').trim();
  if (slug.length === 0 || slug.includes('/') || slug.includes(':')) {
    return undefined;
  }
  if (!/^[a-z0-9][a-z0-9._-]*$/i.test(slug)) {
    return undefined;
  }

  const subtitle = anchor !== undefined && anchor.length > 0
    ? `Wiki 链接直达 · #${anchor}`
    : 'Wiki 链接直达 · 点击直接阅读';
  if (DIRECT_SCP_SLUG_REGEX.test(slug)) {
    const itemId = normalizeCatalogItemId(slug);
    return new CatalogDirectTarget(CatalogSearchTargetKind.SCP, itemId, itemId, subtitle, anchor, false);
  }
  const normalizedSlug = slug.toLowerCase();
  return new CatalogDirectTarget(
    CatalogSearchTargetKind.TALE,
    normalizedSlug,
    normalizedSlug,
    subtitle,
    anchor,
    false
  );
}

/**
 * 将搜索框中的编号缩写（如 CN-2000 / 173 / SCP-173）或中文/主站 Wiki 链接
 * 解析为可直接打开的规范化目标。
 */
export function resolveCatalogDirectTarget(rawQuery: string): CatalogDirectTarget | undefined {
  const trimmed = rawQuery.trim();
  if (trimmed.length === 0) {
    return undefined;
  }

  const lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://') || lower.includes('.wikidot.com/')) {
    return resolveWikiUrlTarget(trimmed);
  }

  const cnMatch = /^CN[\s-]*(\d{1,5})((?:[\s-]+|-)[A-Z0-9-]+)?$/i.exec(trimmed);
  if (cnMatch !== null) {
    const digits = padScpDigits(cnMatch[1]);
    const suffix = cnMatch[2] !== undefined
      ? `-${cnMatch[2].replace(/^[\s-]+/, '').replace(/\s+/g, '-').toUpperCase()}`
      : '';
    const itemId = normalizeCatalogItemId(`SCP-CN-${digits}${suffix}`);
    return new CatalogDirectTarget(
      CatalogSearchTargetKind.SCP,
      itemId,
      itemId,
      '中文原创直达 · 点击立即阅读'
    );
  }

  const scpMatch = /^SCP[\s-]*(?:([A-Z]{2,4})[\s-]*)?(\d{1,5})((?:[\s-]+|-)[A-Z0-9-]+)?$/i.exec(trimmed);
  if (scpMatch !== null) {
    const branchPart = scpMatch[1] !== undefined ? `${scpMatch[1].toUpperCase()}-` : '';
    const digits = padScpDigits(scpMatch[2]);
    const suffix = scpMatch[3] !== undefined
      ? `-${scpMatch[3].replace(/^[\s-]+/, '').replace(/\s+/g, '-').toUpperCase()}`
      : '';
    const itemId = normalizeCatalogItemId(`SCP-${branchPart}${digits}${suffix}`);
    const subtitle = isCnScpItemId(itemId)
      ? '中文原创直达 · 点击立即阅读'
      : '档案编号直达 · 点击立即阅读';
    return new CatalogDirectTarget(
      CatalogSearchTargetKind.SCP,
      itemId,
      itemId,
      subtitle
    );
  }

  if (/^\d{3,4}$/.test(trimmed)) {
    const itemId = normalizeCatalogItemId(`SCP-${trimmed}`);
    return new CatalogDirectTarget(
      CatalogSearchTargetKind.SCP,
      itemId,
      itemId,
      '主站编号直达 · 点击立即阅读'
    );
  }

  return undefined;
}

/** 用当前已索引的档案与故事标题补全直达目标，保留锚点与直达提示。 */
export function enrichDirectTargetTitle(
  target: CatalogDirectTarget,
  entries: CatalogEntry[],
  tales: CatalogTaleEntry[]
): CatalogDirectTarget {
  const anchorSuffix = target.anchor !== undefined && target.anchor.length > 0
    ? ` · #${target.anchor}`
    : '';
  if (target.kind === CatalogSearchTargetKind.SCP) {
    const targetUpper = target.itemId.toUpperCase();
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      if (entry.itemId.toUpperCase() === targetUpper) {
        const resolvedTitle = entry.title.trim().length > 0 ? entry.title : target.itemId;
        const subtitle = target.anchor !== undefined && target.anchor.length > 0
          ? `Wiki 链接直达${anchorSuffix}`
          : (isCnScpItemId(entry.itemId) ? '已收录于中文原创目录 · 点击立即阅读' : '已收录于主站目录 · 点击立即阅读');
        return new CatalogDirectTarget(
          CatalogSearchTargetKind.SCP,
          entry.itemId,
          resolvedTitle,
          subtitle,
          target.anchor,
          true
        );
      }
    }
    return target;
  }

  const targetLower = target.itemId.toLowerCase();
  for (let index = 0; index < tales.length; index++) {
    const tale = tales[index];
    if (tale.id.toLowerCase() === targetLower) {
      const resolvedTitle = tale.title.trim().length > 0 ? tale.title : target.itemId;
      const subtitle = target.anchor !== undefined && target.anchor.length > 0
        ? `Wiki 链接直达${anchorSuffix}`
        : '已收录于故事目录 · 点击立即阅读';
      return new CatalogDirectTarget(
        CatalogSearchTargetKind.TALE,
        tale.id,
        resolvedTitle,
        subtitle,
        target.anchor,
        true
      );
    }
  }
  return target;
}
