import terminalStorySeriesTest from './TerminalStorySeries.test';
import settingsStorageTest from './SettingsStorage.test';

/** Local Hypium entry point for the phone product. */
export default function testsuite(): void {
  terminalStorySeriesTest();
  settingsStorageTest();
}
