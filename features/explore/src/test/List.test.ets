import exploreInitializationTest from './ExploreInitialization.test';
import exploreSnapshotTest from './ExploreSnapshot.test';
import exploreRecommendationServiceTest from './RecommendationService.test';
import exploreRecommendationPreviewTest from './RecommendationPreview.test';
import exploreHomeViewModelTest from './ExploreHomeViewModel.test';
import exploreHtmlParseTaskTest from './ExploreHtmlParseTask.test';

/** Local Hypium entry point for the Explore HAR. */
export default function testsuite(): void {
  exploreInitializationTest();
  exploreSnapshotTest();
  exploreRecommendationServiceTest();
  exploreRecommendationPreviewTest();
  exploreHomeViewModelTest();
  exploreHtmlParseTaskTest();
}
