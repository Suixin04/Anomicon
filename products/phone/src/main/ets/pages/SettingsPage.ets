import { AppInfoPort, HapticFeedbackPort } from 'anomiconbasic';
import {
  SettingsBranding,
  SettingsNavigationTarget,
  SettingsPageBuilder as SettingsFeaturePageBuilder,
  SettingsStorageActions,
  SettingsViewModel
} from 'settings';
import { AppRoutes } from '../navigation/AppRoutes';
import { AppNavigationCoordinator } from '../navigation/AppNavigationCoordinator';

/** Phone-only route mapping for Settings navigation events. */
function routeFor(target: SettingsNavigationTarget): string {
  switch (target) {
    case SettingsNavigationTarget.ABOUT:
      return AppRoutes.ABOUT;
    case SettingsNavigationTarget.CONTENT_LICENSE:
      return AppRoutes.CONTENT_LICENSE;
    case SettingsNavigationTarget.ARCHIVE_3D_GALLERY:
      return AppRoutes.ARCHIVE_3D_GALLERY;
    default:
      throw new Error(`未知设置导航目标：${target}`);
  }
}

/**
 * Thin phone adapter for the Settings feature View.
 *
 * The settings HAR owns the complete visual tree and interaction state.  This
 * product seam injects phone branding, platform effects and product routes.
 */
@Builder
export function SettingsPageBuilder(
  settings: SettingsViewModel,
  appInfo: AppInfoPort,
  hapticService: HapticFeedbackPort,
  storageActions?: SettingsStorageActions
) {
  SettingsFeaturePageBuilder({
    viewModel: settings,
    branding: new SettingsBranding(
      '格异录',
      'Anomicon',
      appInfo.versionName(),
      $r('app.media.appIcon'),
      $r('app.media.cc_logo'),
      $r('app.media.cc_by'),
      $r('app.media.cc_sa')
    ),
    storageActions: storageActions,
    onHaptic: (enabled: boolean): void => {
      hapticService.playSelection(enabled);
    },
    onNavigate: (
      pageStack: NavPathStack | undefined,
      target: SettingsNavigationTarget
    ): void => {
      AppNavigationCoordinator.push(pageStack, routeFor(target));
    }
  });
}
