import {
  ExploreRecommendation,
  ExploreRecommendationEntry,
  exploreDayKey,
  selectExploreIndexes
} from '../domain/ExploreContracts';
import {
  ExploreRecommendationPageGateway,
  PreviewRepository,
  ExploreTitleResolver
} from '../domain/ExploreRepositories';

const RECOMMENDATION_COUNT: number = 6;
const MAX_CANDIDATE_ATTEMPTS: number = 24;
const CANDIDATE_GROUP_SIZE: number = 6;
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

/**
 * 每日推荐直接由随机 SCP 编号驱动：
 * - 当天 batch 0 稳定，次日自然变化；
 * - 手动“换一批”改变 batch salt，生成另一组编号；
 * - 每个编号直接请求中文主站，只有真实存在且能解析标题的页面才会发布。
 *
 * 目录缓存不再参与候选选择，避免“推荐只是浏览过的内容”。
 */
export class RecommendationService {
  private readonly pageGateway: ExploreRecommendationPageGateway;
  private readonly previewRepository: PreviewRepository;
  private readonly titleResolver: ExploreTitleResolver | undefined;

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
    dayKey: string = exploreDayKey()
  ): Promise<ExploreRecommendation[]> {
    const ids = this.generateCandidateIds(batchIndex, dayKey);
    const recommendations: ExploreRecommendation[] = [];
    let failureCount: number = 0;
    for (let start = 0;
      start < ids.length && recommendations.length < RECOMMENDATION_COUNT;
      start += CANDIDATE_GROUP_SIZE) {
      const tasks: Promise<RecommendationResolution>[] = [];
      const end = Math.min(start + CANDIDATE_GROUP_SIZE, ids.length);
      for (let index = start; index < end; index++) {
        tasks.push(this.resolveRecommendation(ids[index]));
      }
      const resolved = await Promise.all(tasks);
      for (let index = 0;
        index < resolved.length && recommendations.length < RECOMMENDATION_COUNT;
        index++) {
        const resolution = resolved[index];
        if (resolution.failed) {
          failureCount += 1;
        }
        if (resolution.recommendation !== undefined) {
          recommendations.push(resolution.recommendation);
        }
      }
    }
    // An empty candidate set is a legitimate result only when every request
    // completed and the sampled wiki pages were genuinely absent/invalid.
    // If at least one transport/cache/preview operation failed, publishing an
    // empty READY state would suppress retries for the rest of the day.
    if (recommendations.length < RECOMMENDATION_COUNT && failureCount > 0) {
      // Do not publish a short list as READY when some of the sampled pages
      // failed to load.  The caller can retain an older card set and expose a
      // retry/partial state instead of silently presenting an incomplete batch.
      throw new Error('今日推荐部分请求失败');
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

  private async resolveRecommendation(itemId: string): Promise<RecommendationResolution> {
    try {
      // 不读取图鉴或文章缓存；随机编号始终由主站响应验证。
      const fetched = await this.pageGateway.fetchPage(`${WIKI_BASE}${itemId.toLowerCase()}`);
      if (!this.isExistingPage(fetched.html)) {
        return new RecommendationResolution(undefined);
      }
      let title = this.extractTitle(fetched.html, itemId);
      // The article shell normally contains only `SCP-xxxx` in #page-title
      // and document.title. Ask the Catalog title port for the real human
      // title, while retaining the page id as a safe fallback for uncached or
      // genuinely untitled pages.
      if (this.titleResolver !== undefined && this.isPlaceholderTitle(itemId, title)) {
        try {
          const resolved = (await this.titleResolver(itemId)).trim();
          if (resolved.length > 0 && !this.isPlaceholderTitle(itemId, resolved)) {
            title = resolved;
          }
        } catch (_error) {
          // A recommendation remains usable when its optional title lookup
          // is offline; the stable SCP id is still shown.
        }
      }
      if (title.length === 0) {
        return new RecommendationResolution(undefined);
      }
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
