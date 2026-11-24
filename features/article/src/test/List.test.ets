import articleDocumentCachePolicyTest from './ArticleCachePolicy.test';
import articleDocumentMapperTest from './ArticleDocumentMapper.test';
import articleNavigationTest from './ArticleNavigation.test';
import articlePayloadCompatibilityTest from './ArticlePayloadCompatibility.test';
import articleRendererTest from './ArticleRenderer.test';
import articleReadingRestoreTest from './ArticleReadingRestore.test';
import articleRequestIdTest from './ArticleRequestId.test';
import articleScrollRestoreCoordinatorTest from './ArticleScrollRestore.test';

/** Local Hypium entry point for the Article HAR. */
export default function testsuite(): void {
  articleDocumentCachePolicyTest();
  articleDocumentMapperTest();
  articleNavigationTest();
  articlePayloadCompatibilityTest();
  articleRendererTest();
  articleReadingRestoreTest();
  articleRequestIdTest();
  articleScrollRestoreCoordinatorTest();
}
