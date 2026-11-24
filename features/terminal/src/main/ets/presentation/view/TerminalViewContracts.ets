import { LibraryContentRef } from 'library';
import { LibraryCollectionMode } from 'library';
import { TerminalViewModel } from '../viewmodel/TerminalViewModel';

/**
 * Product-facing contract for the terminal screen.
 *
 * The feature exposes the contract instead of its storage adapters.  Product
 * navigation remains outside this HAR and is represented by callbacks only.
 */
export interface TerminalViewContract {
  viewModel: TerminalViewModel;
  onOpenContent: (content: LibraryContentRef) => void;
  onOpenCollection: (mode: LibraryCollectionMode) => void;
  onOpenArchive3DGallery?: () => void;
  onOpenSettings?: () => void;
}
