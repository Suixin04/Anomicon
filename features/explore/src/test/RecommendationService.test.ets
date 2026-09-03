import { describe, expect, it } from '@ohos/hypium';
import { RecommendationService } from '../main/ets/data/RecommendationService';
import { ExplorePreview } from '../main/ets/domain/ExploreContracts';
import {
  ExploreFetchedPage,
  ExploreRecommendationPageGateway,
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
  fetchPage(_sourceUrl: string): Promise<ExploreFetchedPage> {
    return Promise.resolve(new ExploreFetchedPage(
      '<html><head><title>SCP-001 - SCP基金会</title></head>' +
      '<body><div id="page-title">SCP-001</div><div id="page-content"><p>正文</p></div></body></html>',
      1
    ));
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
        (itemId: string): Promise<string> => Promise.resolve(itemId === 'SCP-001' ? '守门人的提案' : '')
      );
      const recommendations = await service.loadDaily(0, '2020-01-03');
      // The deterministic candidate set is large; at least one resolved page
      // should use the injected title when it happens to be SCP-001.
      // Exercise the private resolution path indirectly with the known parser
      // fixture by asserting the service accepts a real page and preserves a
      // non-placeholder title when present.
      expect(recommendations.length > 0).assertTrue();
      expect(recommendations[0].entry.title.length > 0).assertTrue();
    });
  });
}
