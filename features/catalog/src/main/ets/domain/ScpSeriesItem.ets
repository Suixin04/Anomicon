const WIKI_BASE: string = 'https://scp-wiki-cn.wikidot.com/';

/** 图鉴分支：主站译文 vs 中文原创。 */
export enum ScpCatalogBranch {
  MAIN = 'main',
  CN = 'cn'
}

/** 系列页描述：id 即页面名（缓存 key），label 为界面标签。 */
export class ScpSeriesDescriptor {
  readonly id: string;
  readonly label: string;
  readonly url: string;
  readonly branch: ScpCatalogBranch;

  constructor(
    id: string,
    label: string,
    url: string,
    branch: ScpCatalogBranch = ScpCatalogBranch.MAIN
  ) {
    this.id = id;
    this.label = label;
    this.url = url;
    this.branch = branch;
  }
}

function buildMainSeriesDescriptors(): ScpSeriesDescriptor[] {
  const list: ScpSeriesDescriptor[] = [];
  list.push(new ScpSeriesDescriptor('scp-series', 'I', `${WIKI_BASE}scp-series`, ScpCatalogBranch.MAIN));
  const labels: string[] = ['II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
  for (let index: number = 0; index < labels.length; index++) {
    const suffix: number = index + 2;
    list.push(
      new ScpSeriesDescriptor(
        `scp-series-${suffix}`,
        labels[index],
        `${WIKI_BASE}scp-series-${suffix}`,
        ScpCatalogBranch.MAIN
      )
    );
  }
  return list;
}

function buildCnSeriesDescriptors(): ScpSeriesDescriptor[] {
  const list: ScpSeriesDescriptor[] = [];
  list.push(new ScpSeriesDescriptor('scp-series-cn', 'CN-I', `${WIKI_BASE}scp-series-cn`, ScpCatalogBranch.CN));
  const labels: string[] = ['CN-II', 'CN-III', 'CN-IV', 'CN-V'];
  for (let index: number = 0; index < labels.length; index++) {
    const suffix: number = index + 2;
    list.push(
      new ScpSeriesDescriptor(
        `scp-series-cn-${suffix}`,
        labels[index],
        `${WIKI_BASE}scp-series-cn-${suffix}`,
        ScpCatalogBranch.CN
      )
    );
  }
  return list;
}

/** 主站系列页 I–X（scp-series / scp-series-2 … scp-series-10）。 */
export const SCP_SERIES: ScpSeriesDescriptor[] = buildMainSeriesDescriptors();

/** 中文原创系列页 CN-I–CN-V（scp-series-cn / scp-series-cn-2 … scp-series-cn-5）。 */
export const SCP_CN_SERIES: ScpSeriesDescriptor[] = buildCnSeriesDescriptors();

/** 全部分支系列（用于全局检索、缓存标题补全与统一索引）。 */
export const ALL_CATALOG_SERIES: ScpSeriesDescriptor[] = SCP_SERIES.concat(SCP_CN_SERIES);

export const DEFAULT_SERIES_ID: string = 'scp-series';

export const DEFAULT_CN_SERIES_ID: string = 'scp-series-cn';

export const ALL_SERIES_ID: string = 'all';

export const ALL_SERIES_LABEL: string = '全部系列';

export function catalogSeriesForBranch(branch: ScpCatalogBranch): ScpSeriesDescriptor[] {
  return branch === ScpCatalogBranch.CN ? SCP_CN_SERIES : SCP_SERIES;
}

export function findCatalogSeriesById(seriesId: string): ScpSeriesDescriptor | undefined {
  const normalized = seriesId.trim().toLowerCase();
  for (let index: number = 0; index < ALL_CATALOG_SERIES.length; index++) {
    if (ALL_CATALOG_SERIES[index].id === normalized) {
      return ALL_CATALOG_SERIES[index];
    }
  }
  return undefined;
}

export function branchOfSeriesId(seriesId: string): ScpCatalogBranch {
  const descriptor = findCatalogSeriesById(seriesId);
  if (descriptor !== undefined) {
    return descriptor.branch;
  }
  return seriesId.trim().toLowerCase().startsWith('scp-series-cn')
    ? ScpCatalogBranch.CN
    : ScpCatalogBranch.MAIN;
}

export function isCnScpItemId(itemId: string): boolean {
  return itemId.trim().toUpperCase().startsWith('SCP-CN-');
}

/** 编号 → 文章页地址（wikidot 对大小写不敏感，统一小写）。 */
export function articleUrlOf(itemId: string): string {
  return `${WIKI_BASE}${itemId.toLowerCase()}`;
}
