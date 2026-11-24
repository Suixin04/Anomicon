/** Platform capabilities consumed by application and presentation code. */
export interface AppInfoPort {
  versionName(): string;
  versionCode(): number;
  versionLabel(): string;
  deviceType(): string;
  osLabel(): string;
}

export interface ClipboardPort {
  copyText(text: string): Promise<void>;
}

export interface HapticFeedbackPort {
  playSelection(enabled: boolean): void;
}

/**
 * Runtime time capability used by activity/accounting policies.
 *
 * `uptime()` must be monotonic (or return `undefined` when the platform
 * cannot provide it); `wallTime()` is only used for persisted timestamps and
 * may therefore follow the user's clock.  Keeping both methods behind one
 * port prevents application/domain code from importing BasicServicesKit.
 */
export interface RuntimeClockPort {
  uptime(): number | undefined;
  wallTime(): number;
}

/** UUID capability used for session identities without leaking ArkTS `util`. */
export interface IdGeneratorPort {
  generate(): string;
}
