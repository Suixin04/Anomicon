import { AppInfoPort } from 'anomiconbasic';
import {
  AboutPageBuilder as SettingsAboutPageBuilder,
  AboutPageContent,
  SettingsViewModel
} from 'settings';

/** Thin phone adapter that supplies product identity to the Settings About View. */
@Builder
export function AboutPageBuilder(appInfo: AppInfoPort, settings: SettingsViewModel) {
  SettingsAboutPageBuilder(new AboutPageContent(
    '格异录',
    'Anomicon',
    appInfo.versionName(),
    $r('app.media.appIcon')
  ), settings);
}
