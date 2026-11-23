import catalogSearchSnapshotTest from './CatalogSearchSnapshot.test';
import scpPageFetchLifecycleTest from './ScpPageFetchLifecycle.test';
import staticCatalogHtmlParserTest from './StaticCatalogHtmlParser.test';
import scpPreviewImageFallbackTest from './ScpPreviewImageFallback.test';
import scpRequestSchedulerTest from './ScpRequestScheduler.test';
import scpPreviewHtmlExtractorTest from './ScpPreviewHtmlExtractor.test';

/** Local Hypium entry point for the Catalog HAR. */
export default function testsuite(): void {
  catalogSearchSnapshotTest();
  scpPageFetchLifecycleTest();
  staticCatalogHtmlParserTest();
  scpPreviewImageFallbackTest();
  scpRequestSchedulerTest();
  scpPreviewHtmlExtractorTest();
}
