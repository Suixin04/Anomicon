import catalogSearchSnapshotTest from './CatalogSearchSnapshot.test';
import catalogDirectTargetTest from './CatalogDirectTarget.test';
import seriesTalesEditionTest from './SeriesTalesEdition.test';
import scpPageFetchLifecycleTest from './ScpPageFetchLifecycle.test';
import staticCatalogHtmlParserTest from './StaticCatalogHtmlParser.test';
import scpPreviewImageFallbackTest from './ScpPreviewImageFallback.test';
import scpRequestSchedulerTest from './ScpRequestScheduler.test';
import scpPreviewHtmlExtractorTest from './ScpPreviewHtmlExtractor.test';

/** Local Hypium entry point for the Catalog HAR. */
export default function testsuite(): void {
  catalogSearchSnapshotTest();
  catalogDirectTargetTest();
  seriesTalesEditionTest();
  scpPageFetchLifecycleTest();
  staticCatalogHtmlParserTest();
  scpPreviewImageFallbackTest();
  scpRequestSchedulerTest();
  scpPreviewHtmlExtractorTest();
}
