import { describe, expect, it } from '@ohos/hypium';
import { RecommendationService } from '../main/ets/data/RecommendationService';
import { ExplorePreview, ExploreRecommendation } from '../main/ets/domain/ExploreContracts';
import {
  ExploreFetchedPage,
  ExploreRecommendationPageGateway,
  ExploreRecommendationProgress,
  PreviewRepository
} from '../main/ets/domain/ExploreRepositories';

class MissingPageGateway implements ExploreRecommendationPageGateway {
  readonly urls: string[] = [];

  fetchPage(sourceUrl: string): Promise<ExploreFetchedPage> {
    this.urls.push(sourceUrl);
    return Promise.resolve(new ExploreFetchedPage('This page does not exist yet', 1));
  }
}

class EmptyPreviewRepository implements PreviewRepository {
  getPreview(_itemId: string): Promise<ExplorePreview> {
    return Promise.resolve(new ExplorePreview());
  }

  resolveFetchedHtml(
    _itemId: string,
    _html: string,
    _fetchedAt?: number
  ): Promise<ExplorePreview> {
    return Promise.resolve(new ExplorePreview());
  }
}

class RecommendationPageGateway implements ExploreRecommendationPageGateway {
  fetchPage(sourceUrl: string): Promise<ExploreFetchedPage> {
    const itemId = sourceUrl.substring(sourceUrl.lastIndexOf('/') + 1).toUpperCase();
    return Promise.resolve(new ExploreFetchedPage(
      `<div id="page-title">${itemId}</div><div id="page-content"><p>正文</p></div>`, 1));
  }
}

class PendingRecommendationPageGateway implements ExploreRecommendationPageGateway {
  readonly urls: string[] = [];
  active: number = 0;
  peak: number = 0;
  private readonly resolvers: Array<(page: ExploreFetchedPage) => void> = [];

  fetchPage(sourceUrl: string): Promise<ExploreFetchedPage> {
    this.urls.push(sourceUrl);
    this.active++;
    this.peak = Math.max(this.peak, this.active);
    return new Promise<ExploreFetchedPage>((resolve: (page: ExploreFetchedPage) => void): void => {
      this.resolvers.push(resolve);
    });
  }

  finish(index: number, exists: boolean = true): void {
    const html = exists ? '<div id="page-title">条目名称</div><div id="page-content">正文</div>' :
      'This page does not exist yet';
    this.active--;
    this.resolvers[index](new ExploreFetchedPage(html, 1));
  }
}

async function drainMicrotasks(count: number = 24): Promise<void> {
  for (let index = 0; index < count; index++) {
    await Promise.resolve();
  }
}

export default function exploreRecommendationServiceTest(): void {
  describe('RecommendationService', () => {
    it('pads one and two digit candidate ids without changing larger ids', 0, async () => {
      const gateway = new MissingPageGateway();
      const service = new RecommendationService(gateway, new EmptyPreviewRepository());

      const recommendations = await service.loadDaily(18, '2020-01-03');

      expect(recommendations.length).assertEqual(0);
      expect(gateway.urls.length).assertEqual(24);
      expect(gateway.urls.indexOf('https://scp-wiki-cn.wikidot.com/scp-007') >= 0).assertTrue();
      expect(gateway.urls.indexOf('https://scp-wiki-cn.wikidot.com/scp-062') >= 0).assertTrue();
      expect(gateway.urls.indexOf('https://scp-wiki-cn.wikidot.com/scp-117') >= 0).assertTrue();
      expect(gateway.urls.indexOf('https://scp-wiki-cn.wikidot.com/scp-2713') >= 0).assertTrue();
    });

    it('resolves a human title when the article shell only contains its SCP id', 0, async () => {
      const service = new RecommendationService(
        new RecommendationPageGateway(),
        new EmptyPreviewRepository(),
        (itemId: string): Promise<string> => Promise.resolve(`档案 ${itemId}`)
      );
      const recommendations = await service.loadDaily(0, '2020-01-03');
      expect(recommendations.length).assertEqual(6);
      expect(recommendations[0].entry.title).assertEqual(`档案 ${recommendations[0].entry.itemId}`);
    });

    it('publishes out of order and immediately refills a failed candidate slot', 0, async () => {
      const gateway = new PendingRecommendationPageGateway();
      const service = new RecommendationService(gateway, new EmptyPreviewRepository());
      const published: ExploreRecommendation[] = [];
      const progress: ExploreRecommendationProgress = {
        isCurrent: (): boolean => true,
        onCandidate: (item: ExploreRecommendation): void => { published.push(item); },
        onTitle: (_id: string, _title: string): void => {}
      };
      const loading = service.loadDaily(0, '2020-01-03', progress);
      expect(gateway.urls.length).assertEqual(6);
      gateway.finish(3);
      await drainMicrotasks();
      expect(published.length).assertEqual(1);
      expect(gateway.urls[3].endsWith(published[0].entry.itemId.toLowerCase())).assertTrue();
      gateway.finish(1, false);
      await drainMicrotasks();
      expect(gateway.urls.length).assertEqual(7);
      expect(published.length).assertEqual(1);
      gateway.finish(6);
      await drainMicrotasks();
      expect(published.length).assertEqual(2);
      gateway.finish(0);
      gateway.finish(2);
      gateway.finish(4);
      gateway.finish(5);
      const items = await loading;
      expect(items.length).assertEqual(6);
      expect(published.length).assertEqual(6);
      expect(items[0].entry.itemId).assertEqual(published[0].entry.itemId);
      expect(gateway.peak).assertEqual(6);
      expect(gateway.urls.length).assertEqual(7);
    });

    it('does not wait for titles and suppresses queued enrichment after invalidation', 0, async () => {
      const titles: Array<(value: string) => void> = [];
      const service = new RecommendationService(new RecommendationPageGateway(), new EmptyPreviewRepository(),
        (_itemId: string): Promise<string> => new Promise<string>((resolve: (value: string) => void): void => {
          titles.push(resolve);
        }));
      const published: ExploreRecommendation[] = [];
      const updatedIds: string[] = [];
      let current: boolean = true;
      const progress: ExploreRecommendationProgress = {
        isCurrent: (): boolean => current,
        onCandidate: (item: ExploreRecommendation): void => { published.push(item); },
        onTitle: (id: string, _title: string): void => { updatedIds.push(id); }
      };
      let completed: boolean = false;
      const loading = service.loadDaily(0, '2020-01-03', progress).then((items: ExploreRecommendation[]) => {
        completed = true;
        return items;
      });
      await drainMicrotasks();
      expect(completed).assertTrue();
      expect(published.length).assertEqual(6);
      expect(published[0].entry.title).assertEqual(published[0].entry.itemId);
      expect(titles.length).assertEqual(2);
      expect(updatedIds.length).assertEqual(0);
      titles[0]('人类可读标题');
      await drainMicrotasks();
      expect(updatedIds[0]).assertEqual(published[0].entry.itemId);
      expect(titles.length).assertEqual(3);
      current = false;
      titles[1]('过期标题');
      titles[2]('过期标题');
      await drainMicrotasks();
      expect(titles.length).assertEqual(3);
      expect(updatedIds.length).assertEqual(1);
      await loading;
    });

    it('shares candidate concurrency with a superseded batch and skips invalid work', 0, async () => {
      const gateway = new PendingRecommendationPageGateway();
      const service = new RecommendationService(gateway, new EmptyPreviewRepository());
      let current: boolean = true;
      const progress: ExploreRecommendationProgress = {
        isCurrent: (): boolean => current,
        onCandidate: (_item: ExploreRecommendation): void => {},
        onTitle: (_id: string, _title: string): void => {}
      };
      const old = service.loadDaily(0, '2020-01-03', progress);
      current = false;
      const next = service.loadDaily(1, '2020-01-03');
      expect(gateway.urls.length).assertEqual(6);
      for (let index = 0; index < 6; index++) {
        gateway.finish(index, false);
      }
      expect((await old).length).assertEqual(0);
      expect(gateway.urls.length).assertEqual(12);
      for (let index = 6; index < 12; index++) {
        gateway.finish(index);
      }
      expect((await next).length).assertEqual(6);
      expect(gateway.peak).assertEqual(6);
    });
  });
}
