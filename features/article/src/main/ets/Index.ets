export {
  ArticleHtmlSource,
  ArticleHtmlSnapshot,
  ArticleHtmlPort,
  ArticleContentSource,
  ArticleLoadResult,
  ArticleContentGateway,
  ArticleViewStatePort,
  ArticleFavoritePort,
  PendingExtraction,
  ReadingSessionPort,
  ArticleDocumentParserPort,
  ArticleExtractionRequest,
  ArticleHistoryPort,
  ArticleHistorySnapshot,
  ArticleMetadataPort,
  ArticleRelatedTale
} from './domain/ArticleContracts';
export {
  ScpArticleDocument,
  ScpBlockType,
  ScpContentBlock,
  ScpFootnote,
  ScpTextSpan,
  ScpTextStyle
} from './domain/ScpDocument';
// Composition returns only domain ports and screen factories. Gateway,
// cache/view-state adapters and the schema mapper remain private to Article.
export {
  ArticleFeatureDependencies,
  ArticleFeatureGraph,
  createArticleDocumentParser,
  createArticleFeatureGraph
} from './composition/ArticleFeatureFactory';
export {
  ArticleViewModel,
  ArticleViewModelListener
} from './presentation/viewmodel/ArticleViewModel';
export { ArticleNativeRenderer } from './presentation/view/ArticleNativeRenderer';
export { ArticleScrollRestore } from './presentation/view/ArticleScrollRestore';
// Public presentation pieces used by the product route adapter. They accept
// only serializable content/preview callbacks; the native parser is the normal
// path and ScpHtmlExtractor is kept as a compatibility adapter below.
export {
  ARTICLE_READING_STATUS_HEIGHT,
  ArticleReadingStatusBar
} from './presentation/view/ArticleReadingStatusBar';
export { ScpImagePreviewer } from './presentation/view/ScpImagePreviewer';
// Legacy ArkWeb is intentionally isolated behind a presentation adapter. The
// adapter exchanges strings/request ids only; no WebView reaches the VM.
export { ScpHtmlExtractor } from './presentation/adapter/ScpHtmlExtractor';
