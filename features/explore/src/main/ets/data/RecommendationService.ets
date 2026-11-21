import {
  ExploreRecommendation,
  ExploreRecommendationEntry,
  exploreDayKey,
  selectExploreIndexes
} from '../domain/ExploreContracts';
import {
  ExploreRecommendationPageGateway,
  ExploreRecommendationProgress,
  PreviewRepository,
  ExploreTitleResolver
} from '../domain/ExploreRepositories';

const RECOMMENDATION_COUNT: number = 6;
const MAX_CANDIDATE_ATTEMPTS: number = 24;
const CANDIDATE_CONCURRENCY: number = 6;
const TITLE_CONCURRENCY: number = 2;
const WIKI_BASE: string = 'https://scp-wiki-cn.wikidot.com/';
/** 主站已接入 I–X 系列；编号以 001–9999 为随机空间，实际存在性由官网响应确认。 */
const SCP_NUMBER_SPACE: number = 9999;

/** Internal candidate outcome; distinguishes a valid missing page from I/O failure. */
class RecommendationResolution {
  readonly recommendation: ExploreRecommendation | undefined;
  readonly failed: boolean;

  constructor(recommendation: ExploreRecommendation | undefined, failed: boolean = false) {
    this.recommendation = recommendation;
    this.failed = failed;
  }
}

/** 跨批次限制在途请求；释放时把名额直接交给队首。 */
class RecommendationWorkLimit {
  private readonly limit: number;
  private readonly waiters: Array<() => void> = [];
  private activeCount: number = 0;

  constructor(limit: number) {
    this.limit = limit;
  }

  async run<T>(task: () => Promise<T>): Promise<T> {
    if (this.activeCount < this.limit) {
      this.activeCount++;
    } else {
      await new Promise<void>((resolve: () => void): void => {
        this.waiters.push(resolve);
      });
    }
    try {
      return await task();
    } finally {
      const next = this.waiters.shift();
      if (next === undefined) {
        this.activeCount--;
      } else {
        next();
      }
    }
  }
}

/**
 * 每日推荐由日键和批次决定候选编号，但按实际可用的顺序发牌。
 * 候选由主站响应验证，目录只用于后台补全显示标题。
 */
export class RecommendationService {
  private readonly pageGateway: ExploreRecommendationPageGateway;
  private readonly previewRepository: PreviewRepository;
  private readonly titleResolver: ExploreTitleResolver | undefined;
  private readonly candidateLimit = new RecommendationWorkLimit(CANDIDATE_CONCURRENCY);
  private readonly titleLimit = new RecommendationWorkLimit(TITLE_CONCURRENCY);

  constructor(
    pageGateway: ExploreRecommendationPageGateway,
    previewRepository: PreviewRepository,
    titleResolver?: ExploreTitleResolver
  ) {
    this.pageGateway = pageGateway;
    this.previewRepository = previewRepository;
    this.titleResolver = titleResolver;
  }

  async loadDaily(
    batchIndex: number = 0,
    dayKey: string = exploreDayKey(),
    progress?: ExploreRecommendationProgress
  ): Promise<ExploreRecommendation[]> {
    const ids = this.generateCandidateIds(batchIndex, dayKey);
    const recommendations: ExploreRecommendation[] = [];
    const titleTasks: Promise<void>[] = [];
    const isCurrent = (): boolean => progress?.isCurrent() ?? true;
    let nextIndex: number = 0;
    let failed: boolean = false;

    // 每个 worker 填一张卡：落空就立即补位，成功后交还名额，不多发候选请求。
    const fillSlot = async (): Promise<void> => {
      while (isCurrent() && nextIndex < ids.length) {
        const id = ids[nextIndex++];
        const resolution = await this.candidateLimit.run<RecommendationResolution>(
          (): Promise<RecommendationResolution> => this.resolveRecommendation(id, isCurrent)
        );
        if (!isCurrent()) {
          return;
        }
        failed = failed || resolution.failed;
        const item = resolution.recommendation;
        if (item === undefined) {
          continue;
        }
        const position = recommendations.length;
        recommendations.push(item);
        progress?.onCandidate(item);
        const titleTask = this.enrichTitle(item, isCurrent).then((title: string): void => {
          if (title.length > 0 && isCurrent()) {
            if (progress === undefined) {
              recommendations[position] = new ExploreRecommendation(
                new ExploreRecommendationEntry(id, title), item.preview);
            } else {
              progress.onTitle(id, title);
            }
          }
        });
        if (progress === undefined) {
          titleTasks.push(titleTask);
        }
        return;
      }
    };
    const workers: Promise<void>[] = [];
    for (let index = 0; index < RECOMMENDATION_COUNT; index++) {
      workers.push(fillSlot());
    }
    // 这里只等批次结束；各 worker 已独立发布结果。
    await Promise.all(workers);
    if (isCurrent() && recommendations.length < RECOMMENDATION_COUNT && failed) {
      throw new Error('今日推荐部分请求失败');
    }
    if (progress === undefined) {
      await Promise.all(titleTasks);
    }
    return recommendations;
  }

  private generateCandidateIds(batchIndex: number, dayKey: string): string[] {
    const indexes = selectExploreIndexes(
      SCP_NUMBER_SPACE,
      MAX_CANDIDATE_ATTEMPTS,
      `wiki-random-recommendations:${batchIndex}`,
      dayKey
    );
    const ids: string[] = [];
    for (let index = 0; index < indexes.length; index++) {
      const numberText = `${indexes[index] + 1}`.padStart(3, '0');
      ids.push(`SCP-${numberText}`);
    }
    return ids;
  }

  private async enrichTitle(item: ExploreRecommendation, isCurrent: () => boolean): Promise<string> {
    const resolver = this.titleResolver;
    const id = item.entry.itemId;
    if (resolver === undefined || !this.isPlaceholderTitle(id, item.entry.title)) {
      return '';
    }
    return this.titleLimit.run<string>(async (): Promise<string> => {
      if (!isCurrent()) {
        return '';
      }
      try {
        const title = (await resolver(id)).trim();
        return this.isPlaceholderTitle(id, title) ? '' : title;
      } catch (_error) {
        return '';
      }
    });
  }

  private async resolveRecommendation(
    itemId: string,
    isCurrent: () => boolean
  ): Promise<RecommendationResolution> {
    if (!isCurrent()) {
      return new RecommendationResolution(undefined);
    }
    try {
      const fetched = await this.pageGateway.fetchPage(`${WIKI_BASE}${itemId.toLowerCase()}`);
      if (!isCurrent() || !this.isExistingPage(fetched.html)) {
        return new RecommendationResolution(undefined);
      }
      const title = this.extractTitle(fetched.html, itemId);
      const info = await this.previewRepository.resolveFetchedHtml(
        itemId,
        fetched.html,
        fetched.fetchedAt
      );
      return new RecommendationResolution(new ExploreRecommendation(
        new ExploreRecommendationEntry(itemId, title),
        info
      ));
    } catch (_error) {
      // Preserve the failure classification so an all-empty offline batch is
      // surfaced to the ViewModel instead of being marked READY for the day.
      return new RecommendationResolution(undefined, true);
    }
  }

  private isPlaceholderTitle(itemId: string, title: string): boolean {
    const normalizedId = itemId.trim().replace(/^\/+/, '').toLowerCase();
    const normalizedTitle = title.trim().toLowerCase();
    return normalizedTitle.length === 0 || normalizedTitle === normalizedId;
  }

  private isExistingPage(html: string): boolean {
    const lower = html.toLowerCase();
    if (lower.indexOf('this page doesn\'t exist yet') >= 0 ||
      lower.indexOf('this page does not exist yet') >= 0 ||
      lower.indexOf('该页面尚不存在') >= 0 ||
      lower.indexOf('页面不存在') >= 0) {
      return false;
    }
    return /<[a-z][^>]*\bid\s*=\s*["']page-content["'][^>]*>/i.test(html);
  }

  private extractTitle(html: string, fallback: string): string {
    const pageTitleIdPattern: RegExp =
      /<(?:div|h1)\b[^>]*id=["']page-title["'][^>]*>([\s\S]*?)<\/(?:div|h1)>/i;
    const pageTitleIdMatch = pageTitleIdPattern.exec(html);
    if (pageTitleIdMatch !== null) {
      const title = this.cleanText(pageTitleIdMatch[1] as string);
      if (title.length > 0) {
        return title;
      }
    }
    const pageTitlePattern: RegExp =
      /<div\b[^>]*class=["'][^"']*\bpage-title\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/i;
    const pageTitleMatch = pageTitlePattern.exec(html);
    if (pageTitleMatch !== null) {
      const title = this.cleanText(pageTitleMatch[1] as string);
      if (title.length > 0) {
        return title;
      }
    }
    const titlePattern: RegExp = /<title[^>]*>([\s\S]*?)<\/title>/i;
    const titleMatch = titlePattern.exec(html);
    if (titleMatch === null) {
      return fallback;
    }
    const title = this.cleanText(titleMatch[1] as string)
      .replace(/\s*[-–—]\s*SCP(?:基金会| Foundation).*$/i, '')
      .trim();
    return title.length > 0 ? title : fallback;
  }

  private cleanText(value: string): string {
    return value
      .replace(/<(script|style)[\s\S]*?<\/\1>/gi, ' ')
      .replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;/gi, ' ')
      .replace(/&amp;/gi, '&')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, '\'')
      .replace(/\s+/g, ' ')
      .trim();
  }
}
