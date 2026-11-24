import { CatalogSearchTargetKind } from '../../domain/CatalogDirectTarget';
import { CatalogSearchViewModel } from '../viewmodel/CatalogSearchViewModel';

/** 统一检索点击或直达动作产生的打开意图。 */
export class CatalogSearchSelection {
  readonly kind: CatalogSearchTargetKind;
  readonly itemId: string;
  readonly title: string;
  readonly anchor?: string;

  constructor(
    kind: CatalogSearchTargetKind,
    itemId: string,
    title: string,
    anchor?: string
  ) {
    this.kind = kind;
    this.itemId = itemId;
    this.title = title;
    this.anchor = anchor;
  }
}

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
  readonly onOpenContent: (selection: CatalogSearchSelection) => void;
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
  readonly onOpenContent: (selection: CatalogSearchSelection) => void;
  readonly materialEnabled: boolean;

  constructor(
    viewModel: CatalogSearchViewModel,
    scroller: Scroller,
    sharedState: CatalogSearchSharedState,
    onOpenContent: (selection: CatalogSearchSelection) => void,
    materialEnabled: boolean = true
  ) {
    this.viewModel = viewModel;
    this.scroller = scroller;
    this.sharedState = sharedState;
    this.onOpenContent = onOpenContent;
    this.materialEnabled = materialEnabled;
  }
}
