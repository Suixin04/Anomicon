import { describe, expect, it } from '@ohos/hypium';
import {
  adaptiveListLanesForWidth,
  adaptivePageMarginForWidth,
  AppWidthBreakpoint,
  autoOpenArticleSidePanel,
  resolveArticleSidebarWidth,
  resolveWidthBreakpoint,
  shouldUseCenterSheet,
  supportsArticleSidePanel,
  supportsSplitNavigation
} from '../main/ets/ui/ResponsiveLayoutPolicy';

export default function responsiveLayoutTest(): void {
  describe('ResponsiveLayoutPolicy', () => {
    it('classifies width breakpoints across SM, MD, LG and XL boundaries', 0, () => {
      expect(resolveWidthBreakpoint(0)).assertEqual(AppWidthBreakpoint.SM);
      expect(resolveWidthBreakpoint(390)).assertEqual(AppWidthBreakpoint.SM);
      expect(resolveWidthBreakpoint(599)).assertEqual(AppWidthBreakpoint.SM);
      expect(resolveWidthBreakpoint(600)).assertEqual(AppWidthBreakpoint.MD);
      expect(resolveWidthBreakpoint(680)).assertEqual(AppWidthBreakpoint.MD);
      expect(resolveWidthBreakpoint(732)).assertEqual(AppWidthBreakpoint.MD);
      expect(resolveWidthBreakpoint(839)).assertEqual(AppWidthBreakpoint.MD);
      expect(resolveWidthBreakpoint(840)).assertEqual(AppWidthBreakpoint.LG);
      expect(resolveWidthBreakpoint(960)).assertEqual(AppWidthBreakpoint.LG);
      expect(resolveWidthBreakpoint(1113)).assertEqual(AppWidthBreakpoint.LG);
      expect(resolveWidthBreakpoint(1200)).assertEqual(AppWidthBreakpoint.XL);
      expect(resolveWidthBreakpoint(1440)).assertEqual(AppWidthBreakpoint.XL);
    });

    it('matches HdsTitleBar adaptive page margins across container widths', 0, () => {
      expect(adaptivePageMarginForWidth(0)).assertEqual(16);
      expect(adaptivePageMarginForWidth(-120)).assertEqual(16);
      expect(adaptivePageMarginForWidth(390)).assertEqual(16);
      expect(adaptivePageMarginForWidth(599)).assertEqual(16);
      expect(adaptivePageMarginForWidth(600)).assertEqual(24);
      expect(adaptivePageMarginForWidth(680)).assertEqual(24);
      expect(adaptivePageMarginForWidth(732)).assertEqual(24);
      expect(adaptivePageMarginForWidth(839)).assertEqual(24);
      expect(adaptivePageMarginForWidth(840)).assertEqual(32);
      expect(adaptivePageMarginForWidth(960)).assertEqual(32);
      expect(adaptivePageMarginForWidth(1113)).assertEqual(32);
      expect(adaptivePageMarginForWidth(1200)).assertEqual(32);
      expect(adaptivePageMarginForWidth(1440)).assertEqual(32);
    });

    it('resolves list lanes, split navigation, sheets and article workbench thresholds', 0, () => {
      expect(adaptiveListLanesForWidth(0)).assertEqual(1);
      expect(adaptiveListLanesForWidth(390)).assertEqual(1);
      expect(adaptiveListLanesForWidth(599)).assertEqual(1);
      expect(adaptiveListLanesForWidth(600)).assertEqual(1);
      expect(adaptiveListLanesForWidth(680)).assertEqual(2);
      expect(adaptiveListLanesForWidth(732)).assertEqual(2);
      expect(adaptiveListLanesForWidth(1113)).assertEqual(2);

      expect(supportsSplitNavigation(839)).assertFalse();
      expect(supportsSplitNavigation(840)).assertTrue();
      expect(supportsSplitNavigation(1113)).assertTrue();

      expect(supportsArticleSidePanel(599)).assertFalse();
      expect(supportsArticleSidePanel(600)).assertFalse();
      expect(supportsArticleSidePanel(680)).assertTrue();
      expect(supportsArticleSidePanel(732)).assertTrue();

      expect(autoOpenArticleSidePanel(840)).assertFalse();
      expect(autoOpenArticleSidePanel(960)).assertTrue();
      expect(autoOpenArticleSidePanel(1113)).assertTrue();

      expect(shouldUseCenterSheet(599)).assertFalse();
      expect(shouldUseCenterSheet(600)).assertTrue();
      expect(shouldUseCenterSheet(1113)).assertTrue();

      expect(resolveArticleSidebarWidth(712)).assertEqual(272);
      expect(resolveArticleSidebarWidth(732)).assertEqual(272);
      expect(resolveArticleSidebarWidth(840)).assertEqual(288);
      expect(resolveArticleSidebarWidth(960)).assertEqual(336);
      expect(resolveArticleSidebarWidth(1440)).assertEqual(336);
    });
  });
}
