import { CatalogSearchViewModel } from '../viewmodel/CatalogSearchViewModel';

/**
 * App-scoped series/query bridge supplied by the product host.
 *
 * The Catalog View can preserve cross-route state without importing
 * AppStorageV2 or constructing a product singleton itself.
 */
export interface CatalogSearchSharedState {
  readonly query: string;
  readonly seriesId: string;
  setQuery(value: string): void;
  setSeriesId(id: string): void;
}

/** Narrow input/effect surface for the device-independent search content. */
export interface CatalogSearchViewContract {
  readonly viewModel: CatalogSearchViewModel;
  readonly scroller: Scroller;
  readonly sharedState: CatalogSearchSharedState;
  readonly onOpenContent: (itemId: string, title: string) => void;
  readonly materialEnabled: boolean;
}

/**
 * Typed Builder input for ArkTS callers.
 *
 * Exporting a concrete immutable value prevents an ArkUI Builder invocation
 * from degrading its argument into an untyped object literal at a HAR seam.
 */
export class CatalogSearchViewInput implements CatalogSearchViewContract {
  readonly viewModel: CatalogSearchViewModel;
  readonly scroller: Scroller;
  readonly sharedState: CatalogSearchSharedState;
  readonly onOpenContent: (itemId: string, title: string) => void;
  readonly materialEnabled: boolean;

  constructor(
    viewModel: CatalogSearchViewModel,
    scroller: Scroller,
    sharedState: CatalogSearchSharedState,
    onOpenContent: (itemId: string, title: string) => void,
    materialEnabled: boolean = true
  ) {
    this.viewModel = viewModel;
    this.scroller = scroller;
    this.sharedState = sharedState;
    this.onOpenContent = onOpenContent;
    this.materialEnabled = materialEnabled;
  }
}
