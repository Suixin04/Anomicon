export enum ThemeMode {
  SYSTEM = 'system',
  LIGHT = 'light',
  DARK = 'dark'
}

export enum ComplexPageMode {
  SMART = 'smart',
  PROMPT_ONLY = 'prompt_only',
  ALWAYS_NATIVE = 'always_native'
}

export enum ReadingTextAlign {
  JUSTIFY = 'justify',
  START = 'start'
}

export class ReadingSettingsRange {
  static readonly FONT_SIZE_MIN: number = 14;
  static readonly FONT_SIZE_DEFAULT: number = 18;
  static readonly FONT_SIZE_MAX: number = 22;
  static readonly FONT_SIZE_STEP: number = 0.01;
  static readonly LINE_HEIGHT_MIN: number = 1.2;
  static readonly LINE_HEIGHT_DEFAULT: number = 1.6;
  static readonly LINE_HEIGHT_MAX: number = 2.0;
  static readonly LINE_HEIGHT_STEP: number = 0.001;
}

/** 与存储和 ArkUI 无关的设置快照。 */
export class AppSettings {
  readonly themeMode: ThemeMode;
  readonly hapticEnabled: boolean;
  readonly immersiveMaterialEnabled: boolean;
  readonly fontSize: number;
  readonly lineHeightMultiple: number;
  readonly complexPageMode: ComplexPageMode;
  readonly defaultRevealHiddenText: boolean;
  readonly readingTextAlign: ReadingTextAlign;
  readonly keepScreenOnReading: boolean;

  constructor(
    themeMode: ThemeMode = ThemeMode.SYSTEM,
    hapticEnabled: boolean = true,
    immersiveMaterialEnabled: boolean = true,
    fontSize: number = ReadingSettingsRange.FONT_SIZE_DEFAULT,
    lineHeightMultiple: number = ReadingSettingsRange.LINE_HEIGHT_DEFAULT,
    complexPageMode: ComplexPageMode = ComplexPageMode.SMART,
    defaultRevealHiddenText: boolean = false,
    readingTextAlign: ReadingTextAlign = ReadingTextAlign.JUSTIFY,
    keepScreenOnReading: boolean = false
  ) {
    this.themeMode = themeMode;
    this.hapticEnabled = hapticEnabled;
    this.immersiveMaterialEnabled = immersiveMaterialEnabled;
    this.fontSize = normalizeReadingFontSize(fontSize);
    this.lineHeightMultiple = normalizeReadingLineHeight(lineHeightMultiple);
    this.complexPageMode = complexPageMode;
    this.defaultRevealHiddenText = defaultRevealHiddenText;
    this.readingTextAlign = readingTextAlign;
    this.keepScreenOnReading = keepScreenOnReading;
  }
}

export function normalizeReadingFontSize(value: number): number {
  if (!Number.isFinite(value)) {
    return ReadingSettingsRange.FONT_SIZE_DEFAULT;
  }
  const clamped = Math.max(
    ReadingSettingsRange.FONT_SIZE_MIN,
    Math.min(ReadingSettingsRange.FONT_SIZE_MAX, value)
  );
  return Math.round(clamped / ReadingSettingsRange.FONT_SIZE_STEP) *
    ReadingSettingsRange.FONT_SIZE_STEP;
}

export function normalizeReadingLineHeight(value: number): number {
  if (!Number.isFinite(value)) {
    return ReadingSettingsRange.LINE_HEIGHT_DEFAULT;
  }
  const clamped = Math.max(
    ReadingSettingsRange.LINE_HEIGHT_MIN,
    Math.min(ReadingSettingsRange.LINE_HEIGHT_MAX, value)
  );
  return Math.round(clamped / ReadingSettingsRange.LINE_HEIGHT_STEP) *
    ReadingSettingsRange.LINE_HEIGHT_STEP;
}

export function parseComplexPageMode(raw: string | undefined): ComplexPageMode {
  if (raw === ComplexPageMode.PROMPT_ONLY) {
    return ComplexPageMode.PROMPT_ONLY;
  }
  if (raw === ComplexPageMode.ALWAYS_NATIVE) {
    return ComplexPageMode.ALWAYS_NATIVE;
  }
  return ComplexPageMode.SMART;
}

export function parseReadingTextAlign(raw: string | undefined): ReadingTextAlign {
  if (raw === ReadingTextAlign.START) {
    return ReadingTextAlign.START;
  }
  return ReadingTextAlign.JUSTIFY;
}

export function formatFontSizeLabel(value: number): string {
  return `${normalizeReadingFontSize(value).toFixed(1)} fp`;
}

export function formatLineHeightLabel(value: number): string {
  return `${normalizeReadingLineHeight(value).toFixed(2)}×`;
}

export function formatStorageBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) {
    return '0 B';
  }
  if (bytes < 1024) {
    return `${Math.round(bytes)} B`;
  }
  const kb = bytes / 1024;
  if (kb < 1024) {
    return `${kb >= 100 ? Math.round(kb) : kb.toFixed(1)} KB`;
  }
  const mb = kb / 1024;
  if (mb < 1024) {
    return `${mb >= 100 ? mb.toFixed(0) : mb.toFixed(1)} MB`;
  }
  const gb = mb / 1024;
  return `${gb.toFixed(2)} GB`;
}
