import { describe, expect, it } from '@ohos/hypium';
import {
  AppSettings,
  ComplexPageMode,
  ReadingSettingsRange,
  ReadingTextAlign,
  ThemeMode,
  formatFontSizeLabel,
  formatLineHeightLabel,
  formatStorageBytes,
  parseComplexPageMode,
  parseReadingTextAlign
} from '../main/ets/domain/SettingsModels';
import { SettingsRepository, ThemeModeApplier } from '../main/ets/domain/SettingsRepository';
import { SettingsViewModel } from '../main/ets/presentation/viewmodel/SettingsViewModel';

class FakeSettingsRepository implements SettingsRepository {
  lastError?: string = undefined;
  stored: AppSettings = new AppSettings();
  failNextSave: boolean = false;
  appliedModes: ThemeMode[] = [];

  load(): AppSettings {
    return this.stored;
  }

  saveThemeMode(value: ThemeMode): boolean {
    if (this.failNextSave) {
      this.lastError = '写入失败';
      return false;
    }
    this.lastError = undefined;
    this.stored = new AppSettings(
      value,
      this.stored.hapticEnabled,
      this.stored.immersiveMaterialEnabled,
      this.stored.fontSize,
      this.stored.lineHeightMultiple,
      this.stored.complexPageMode,
      this.stored.defaultRevealHiddenText,
      this.stored.readingTextAlign,
      this.stored.keepScreenOnReading
    );
    return true;
  }

  saveHapticEnabled(value: boolean): boolean {
    if (this.failNextSave) {
      this.lastError = '写入失败';
      return false;
    }
    this.lastError = undefined;
    this.stored = new AppSettings(
      this.stored.themeMode,
      value,
      this.stored.immersiveMaterialEnabled,
      this.stored.fontSize,
      this.stored.lineHeightMultiple,
      this.stored.complexPageMode,
      this.stored.defaultRevealHiddenText,
      this.stored.readingTextAlign,
      this.stored.keepScreenOnReading
    );
    return true;
  }

  saveImmersiveMaterialEnabled(value: boolean): boolean {
    if (this.failNextSave) {
      this.lastError = '写入失败';
      return false;
    }
    this.lastError = undefined;
    this.stored = new AppSettings(
      this.stored.themeMode,
      this.stored.hapticEnabled,
      value,
      this.stored.fontSize,
      this.stored.lineHeightMultiple,
      this.stored.complexPageMode,
      this.stored.defaultRevealHiddenText,
      this.stored.readingTextAlign,
      this.stored.keepScreenOnReading
    );
    return true;
  }

  saveFontSize(value: number): boolean {
    if (this.failNextSave) {
      this.lastError = '写入失败';
      return false;
    }
    this.lastError = undefined;
    this.stored = new AppSettings(
      this.stored.themeMode,
      this.stored.hapticEnabled,
      this.stored.immersiveMaterialEnabled,
      value,
      this.stored.lineHeightMultiple,
      this.stored.complexPageMode,
      this.stored.defaultRevealHiddenText,
      this.stored.readingTextAlign,
      this.stored.keepScreenOnReading
    );
    return true;
  }

  saveLineHeightMultiple(value: number): boolean {
    if (this.failNextSave) {
      this.lastError = '写入失败';
      return false;
    }
    this.lastError = undefined;
    this.stored = new AppSettings(
      this.stored.themeMode,
      this.stored.hapticEnabled,
      this.stored.immersiveMaterialEnabled,
      this.stored.fontSize,
      value,
      this.stored.complexPageMode,
      this.stored.defaultRevealHiddenText,
      this.stored.readingTextAlign,
      this.stored.keepScreenOnReading
    );
    return true;
  }

  saveComplexPageMode(value: ComplexPageMode): boolean {
    if (this.failNextSave) {
      this.lastError = '写入失败';
      return false;
    }
    this.lastError = undefined;
    this.stored = new AppSettings(
      this.stored.themeMode,
      this.stored.hapticEnabled,
      this.stored.immersiveMaterialEnabled,
      this.stored.fontSize,
      this.stored.lineHeightMultiple,
      value,
      this.stored.defaultRevealHiddenText,
      this.stored.readingTextAlign,
      this.stored.keepScreenOnReading
    );
    return true;
  }

  saveDefaultRevealHiddenText(value: boolean): boolean {
    if (this.failNextSave) {
      this.lastError = '写入失败';
      return false;
    }
    this.lastError = undefined;
    this.stored = new AppSettings(
      this.stored.themeMode,
      this.stored.hapticEnabled,
      this.stored.immersiveMaterialEnabled,
      this.stored.fontSize,
      this.stored.lineHeightMultiple,
      this.stored.complexPageMode,
      value,
      this.stored.readingTextAlign,
      this.stored.keepScreenOnReading
    );
    return true;
  }

  saveReadingTextAlign(value: ReadingTextAlign): boolean {
    if (this.failNextSave) {
      this.lastError = '写入失败';
      return false;
    }
    this.lastError = undefined;
    this.stored = new AppSettings(
      this.stored.themeMode,
      this.stored.hapticEnabled,
      this.stored.immersiveMaterialEnabled,
      this.stored.fontSize,
      this.stored.lineHeightMultiple,
      this.stored.complexPageMode,
      this.stored.defaultRevealHiddenText,
      value,
      this.stored.keepScreenOnReading
    );
    return true;
  }

  saveKeepScreenOnReading(value: boolean): boolean {
    if (this.failNextSave) {
      this.lastError = '写入失败';
      return false;
    }
    this.lastError = undefined;
    this.stored = new AppSettings(
      this.stored.themeMode,
      this.stored.hapticEnabled,
      this.stored.immersiveMaterialEnabled,
      this.stored.fontSize,
      this.stored.lineHeightMultiple,
      this.stored.complexPageMode,
      this.stored.defaultRevealHiddenText,
      this.stored.readingTextAlign,
      value,
      this.stored.starterGuideDismissed
    );
    return true;
  }

  saveStarterGuideDismissed(value: boolean): boolean {
    if (this.failNextSave) {
      this.lastError = '写入失败';
      return false;
    }
    this.lastError = undefined;
    this.stored = new AppSettings(
      this.stored.themeMode,
      this.stored.hapticEnabled,
      this.stored.immersiveMaterialEnabled,
      this.stored.fontSize,
      this.stored.lineHeightMultiple,
      this.stored.complexPageMode,
      this.stored.defaultRevealHiddenText,
      this.stored.readingTextAlign,
      this.stored.keepScreenOnReading,
      value
    );
    return true;
  }

  flush(): Promise<void> {
    return Promise.resolve();
  }
}

class FakeThemeApplier implements ThemeModeApplier {
  applied: ThemeMode[] = [];

  apply(value: ThemeMode): void {
    this.applied.push(value);
  }
}

export default function settingsViewModelTest(): void {
  describe('SettingsModelsAndHelpers', () => {
    it('normalizes defaults and parses reading preferences', 0, () => {
      const defaults = new AppSettings();
      expect(defaults.themeMode).assertEqual(ThemeMode.SYSTEM);
      expect(defaults.hapticEnabled).assertTrue();
      expect(defaults.immersiveMaterialEnabled).assertTrue();
      expect(defaults.fontSize).assertEqual(ReadingSettingsRange.FONT_SIZE_DEFAULT);
      expect(defaults.lineHeightMultiple).assertEqual(ReadingSettingsRange.LINE_HEIGHT_DEFAULT);
      expect(defaults.complexPageMode).assertEqual(ComplexPageMode.SMART);
      expect(defaults.defaultRevealHiddenText).assertFalse();
      expect(defaults.readingTextAlign).assertEqual(ReadingTextAlign.JUSTIFY);
      expect(defaults.keepScreenOnReading).assertFalse();
      expect(defaults.starterGuideDismissed).assertFalse();

      const clamped = new AppSettings(ThemeMode.DARK, false, false, 99, 0.2);
      expect(clamped.fontSize).assertEqual(ReadingSettingsRange.FONT_SIZE_MAX);
      expect(clamped.lineHeightMultiple).assertEqual(ReadingSettingsRange.LINE_HEIGHT_MIN);

      expect(parseComplexPageMode('prompt_only')).assertEqual(ComplexPageMode.PROMPT_ONLY);
      expect(parseComplexPageMode('always_native')).assertEqual(ComplexPageMode.ALWAYS_NATIVE);
      expect(parseComplexPageMode('invalid')).assertEqual(ComplexPageMode.SMART);
      expect(parseReadingTextAlign('start')).assertEqual(ReadingTextAlign.START);
      expect(parseReadingTextAlign(undefined)).assertEqual(ReadingTextAlign.JUSTIFY);
    });

    it('formats typography labels and storage sizes cleanly', 0, () => {
      expect(formatFontSizeLabel(18)).assertEqual('18.0 fp');
      expect(formatLineHeightLabel(1.6)).assertEqual('1.60×');
      expect(formatStorageBytes(0)).assertEqual('0 B');
      expect(formatStorageBytes(-5)).assertEqual('0 B');
      expect(formatStorageBytes(512)).assertEqual('512 B');
      expect(formatStorageBytes(1536)).assertEqual('1.5 KB');
      expect(formatStorageBytes(2 * 1024 * 1024 + 512 * 1024)).assertEqual('2.5 MB');
      expect(formatStorageBytes(2 * 1024 * 1024 * 1024)).assertEqual('2.00 GB');
    });
  });

  describe('SettingsViewModelState', () => {
    it('updates new preferences, resets typography, and handles persistence failures', 0, () => {
      const repo = new FakeSettingsRepository();
      const applier = new FakeThemeApplier();
      const vm = new SettingsViewModel(repo, applier);

      expect(vm.setComplexPageMode(ComplexPageMode.PROMPT_ONLY)).assertTrue();
      expect(vm.complexPageMode).assertEqual(ComplexPageMode.PROMPT_ONLY);

      expect(vm.setDefaultRevealHiddenText(true)).assertTrue();
      expect(vm.defaultRevealHiddenText).assertTrue();

      expect(vm.setReadingTextAlign(ReadingTextAlign.START)).assertTrue();
      expect(vm.readingTextAlign).assertEqual(ReadingTextAlign.START);

      expect(vm.setKeepScreenOnReading(true)).assertTrue();
      expect(vm.keepScreenOnReading).assertTrue();

      expect(vm.setStarterGuideDismissed(true)).assertTrue();
      expect(vm.starterGuideDismissed).assertTrue();

      expect(vm.setFontSize(20.5)).assertTrue();
      expect(vm.setLineHeightMultiple(1.85)).assertTrue();
      expect(vm.resetReadingTypography()).assertTrue();
      expect(vm.fontSize).assertEqual(ReadingSettingsRange.FONT_SIZE_DEFAULT);
      expect(vm.lineHeightMultiple).assertEqual(ReadingSettingsRange.LINE_HEIGHT_DEFAULT);
      expect(vm.readingTextAlign).assertEqual(ReadingTextAlign.JUSTIFY);

      repo.failNextSave = true;
      expect(vm.setComplexPageMode(ComplexPageMode.ALWAYS_NATIVE)).assertFalse();
      expect(vm.complexPageMode).assertEqual(ComplexPageMode.PROMPT_ONLY);
      expect(vm.errorMessage).assertEqual('写入失败');

      expect(vm.setDefaultRevealHiddenText(false)).assertFalse();
      expect(vm.defaultRevealHiddenText).assertTrue();

      expect(vm.setStarterGuideDismissed(false)).assertFalse();
      expect(vm.starterGuideDismissed).assertTrue();
    });

    it('preserves active state on failed retryLoad and recovers when storage succeeds', 0, () => {
      const repo = new FakeSettingsRepository();
      const applier = new FakeThemeApplier();
      const vm = new SettingsViewModel(repo, applier);

      expect(vm.setReadingTextAlign(ReadingTextAlign.START)).assertTrue();
      repo.stored = new AppSettings(ThemeMode.DARK);
      repo.lastError = '暂不可用';
      vm.retryLoad();
      expect(vm.readingTextAlign).assertEqual(ReadingTextAlign.START);
      expect(vm.errorMessage).assertEqual('暂不可用');

      repo.lastError = undefined;
      repo.stored = new AppSettings(
        ThemeMode.DARK,
        true,
        false,
        19.5,
        1.75,
        ComplexPageMode.ALWAYS_NATIVE,
        true,
        ReadingTextAlign.JUSTIFY,
        true
      );
      vm.retryLoad();
      expect(vm.themeMode).assertEqual(ThemeMode.DARK);
      expect(vm.complexPageMode).assertEqual(ComplexPageMode.ALWAYS_NATIVE);
      expect(vm.keepScreenOnReading).assertTrue();
      expect(vm.errorMessage).assertEqual('');
      expect(applier.applied.length).assertEqual(1);
    });
  });
}
