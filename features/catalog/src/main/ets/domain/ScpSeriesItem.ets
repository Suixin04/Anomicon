const WIKI_BASE: string = 'https://scp-wiki-cn.wikidot.com/';

/** 主站系列页描述：id 即页面名（缓存 key），label 为界面标签。 */
export class ScpSeriesDescriptor {
  readonly id: string;
  readonly label: string;
  readonly url: string;

  constructor(id: string, label: string, url: string) {
    this.id = id;
    this.label = label;
    this.url = url;
  }
}

function buildSeriesDescriptors(): ScpSeriesDescriptor[] {
  const list: ScpSeriesDescriptor[] = [];
  list.push(new ScpSeriesDescriptor('scp-series', 'I', `${WIKI_BASE}scp-series`));
  const labels: string[] = ['II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
  for (let index: number = 0; index < labels.length; index++) {
    const suffix: number = index + 2;
    list.push(new ScpSeriesDescriptor(`scp-series-${suffix}`, labels[index], `${WIKI_BASE}scp-series-${suffix}`));
  }
  return list;
}

/** 主站系列页 I–X（scp-series / scp-series-2 … scp-series-10）。 */
export const SCP_SERIES: ScpSeriesDescriptor[] = buildSeriesDescriptors();

export const DEFAULT_SERIES_ID: string = 'scp-series';

export const ALL_SERIES_ID: string = 'all';

export const ALL_SERIES_LABEL: string = '全部系列';

/** 编号 → 文章页地址（wikidot 对大小写不敏感，统一小写）。 */
export function articleUrlOf(itemId: string): string {
  return `${WIKI_BASE}${itemId.toLowerCase()}`;
}
