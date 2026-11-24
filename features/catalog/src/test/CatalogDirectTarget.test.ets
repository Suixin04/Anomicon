import { describe, expect, it } from '@ohos/hypium';
import {
  CatalogEntry,
  CatalogTaleEntry
} from '../main/ets/domain/CatalogContracts';
import {
  CatalogSearchTargetKind,
  enrichDirectTargetTitle,
  resolveCatalogDirectTarget
} from '../main/ets/domain/CatalogDirectTarget';
import { filterCatalogEntries } from '../main/ets/domain/CatalogRepositories';
import {
  ALL_CATALOG_SERIES,
  branchOfSeriesId,
  findCatalogSeriesById,
  SCP_CN_SERIES,
  SCP_SERIES,
  ScpCatalogBranch
} from '../main/ets/domain/ScpSeriesItem';

export default function catalogDirectTargetTest(): void {
  describe('CatalogDirectTargetContract', () => {
    it('resolves CN shorthands and zero-pads short numbers', 0, () => {
      const cn2000 = resolveCatalogDirectTarget('CN-2000');
      expect(cn2000 !== undefined).assertTrue();
      expect(cn2000?.kind).assertEqual(CatalogSearchTargetKind.SCP);
      expect(cn2000?.itemId).assertEqual('SCP-CN-2000');
      expect(cn2000?.anchor === undefined).assertTrue();

      const compactCn = resolveCatalogDirectTarget('cn2000');
      expect(compactCn?.kind).assertEqual(CatalogSearchTargetKind.SCP);
      expect(compactCn?.itemId).assertEqual('SCP-CN-2000');

      const shortCn = resolveCatalogDirectTarget('CN 1');
      expect(shortCn?.kind).assertEqual(CatalogSearchTargetKind.SCP);
      expect(shortCn?.itemId).assertEqual('SCP-CN-001');
    });

    it('resolves explicit SCP IDs and 3-4 digit shorthands', 0, () => {
      const bare173 = resolveCatalogDirectTarget('173');
      expect(bare173?.kind).assertEqual(CatalogSearchTargetKind.SCP);
      expect(bare173?.itemId).assertEqual('SCP-173');

      const explicit173 = resolveCatalogDirectTarget('scp 173');
      expect(explicit173?.itemId).assertEqual('SCP-173');

      const shortZero55 = resolveCatalogDirectTarget('scp 55');
      expect(shortZero55?.itemId).assertEqual('SCP-055');

      const jokeVariant = resolveCatalogDirectTarget('SCP-173-J');
      expect(jokeVariant?.kind).assertEqual(CatalogSearchTargetKind.SCP);
      expect(jokeVariant?.itemId).assertEqual('SCP-173-J');
    });

    it('resolves Chinese and English Wiki URLs including anchor fragments and rejects unknown origins', 0, () => {
      const taskForces = resolveCatalogDirectTarget('https://scp-wiki-cn.wikidot.com/task-forces#alpha-1');
      expect(taskForces !== undefined).assertTrue();
      expect(taskForces?.kind).assertEqual(CatalogSearchTargetKind.TALE);
      expect(taskForces?.itemId).assertEqual('task-forces');
      expect(taskForces?.anchor).assertEqual('alpha-1');
      expect(taskForces?.subtitle.includes('#alpha-1')).assertTrue();

      const cnUrlWithQuery = resolveCatalogDirectTarget('https://scp-wiki-cn.wikidot.com/scp-cn-2000?utm=1#sec-2');
      expect(cnUrlWithQuery?.kind).assertEqual(CatalogSearchTargetKind.SCP);
      expect(cnUrlWithQuery?.itemId).assertEqual('SCP-CN-2000');
      expect(cnUrlWithQuery?.anchor).assertEqual('sec-2');

      const enUrl = resolveCatalogDirectTarget('https://scp-wiki.wikidot.com/scp-2521');
      expect(enUrl?.kind).assertEqual(CatalogSearchTargetKind.SCP);
      expect(enUrl?.itemId).assertEqual('SCP-2521');
      expect(enUrl?.anchor === undefined).assertTrue();

      expect(resolveCatalogDirectTarget('https://example.com/scp-173') === undefined).assertTrue();
      expect(resolveCatalogDirectTarget('https://scp-wiki-cn.wikidot.com/system:recent-changes') === undefined).assertTrue();
      expect(resolveCatalogDirectTarget('https://scp-wiki-cn.wikidot.com/local--files/scp-173/img.jpg') === undefined).assertTrue();
      expect(resolveCatalogDirectTarget('逆模因') === undefined).assertTrue();
    });

    it('enriches matched SCP and Tale direct targets while preserving anchors', 0, () => {
      const entries = [
        new CatalogEntry('SCP-CN-2000', '混沌理论'),
        new CatalogEntry('SCP-173', '雕像 - 最初之作')
      ];
      const tales = [
        new CatalogTaleEntry('antimemetics-division-hub', '逆模因部中心页')
      ];

      const rawScp = resolveCatalogDirectTarget('CN-2000')!;
      const enrichedScp = enrichDirectTargetTitle(rawScp, entries, tales);
      expect(enrichedScp.matched).assertTrue();
      expect(enrichedScp.itemId).assertEqual('SCP-CN-2000');
      expect(enrichedScp.title).assertEqual('混沌理论');

      const rawTale = resolveCatalogDirectTarget('https://scp-wiki-cn.wikidot.com/antimemetics-division-hub#part-1')!;
      const enrichedTale = enrichDirectTargetTitle(rawTale, entries, tales);
      expect(enrichedTale.matched).assertTrue();
      expect(enrichedTale.itemId).assertEqual('antimemetics-division-hub');
      expect(enrichedTale.title).assertEqual('逆模因部中心页');
      expect(enrichedTale.anchor).assertEqual('part-1');
      expect(enrichedTale.subtitle.includes('#part-1')).assertTrue();
    });

    it('supports compact catalog filtering and ranks exact before prefix and substring matches', 0, () => {
      const entries = [
        new CatalogEntry('SCP-1730', 'Site-13发生了什么？'),
        new CatalogEntry('SCP-CN-173', '测试原创'),
        new CatalogEntry('SCP-173', '雕像 - 最初之作'),
        new CatalogEntry('SCP-CN-2000', '混沌理论')
      ];

      const numFiltered = filterCatalogEntries(entries, '173');
      expect(numFiltered.length).assertEqual(3);
      expect(numFiltered[0].itemId).assertEqual('SCP-173');
      expect(numFiltered[1].itemId).assertEqual('SCP-1730');
      expect(numFiltered[2].itemId).assertEqual('SCP-CN-173');

      const compactCn = filterCatalogEntries(entries, 'cn2000');
      expect(compactCn.length).assertEqual(1);
      expect(compactCn[0].itemId).assertEqual('SCP-CN-2000');

      const spacedCn = filterCatalogEntries(entries, 'CN 2000');
      expect(spacedCn.length).assertEqual(1);
      expect(spacedCn[0].itemId).assertEqual('SCP-CN-2000');
    });

    it('exposes Main I-X and CN I-V series descriptors consistently', 0, () => {
      expect(SCP_SERIES.length).assertEqual(10);
      expect(SCP_CN_SERIES.length).assertEqual(5);
      expect(ALL_CATALOG_SERIES.length).assertEqual(15);
      expect(branchOfSeriesId('scp-series-cn-3')).assertEqual(ScpCatalogBranch.CN);
      expect(branchOfSeriesId('scp-series-4')).assertEqual(ScpCatalogBranch.MAIN);
      expect(findCatalogSeriesById('scp-series-cn-3')?.label).assertEqual('CN-III');
      expect(findCatalogSeriesById('scp-series-cn-5')?.url).assertEqual('https://scp-wiki-cn.wikidot.com/scp-series-cn-5');
    });
  });
}
