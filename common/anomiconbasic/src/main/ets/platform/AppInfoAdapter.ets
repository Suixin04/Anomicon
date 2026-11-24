import { bundleManager } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { AppInfoPort } from './PlatformPorts';

/** HarmonyOS implementation of the app-info port. */
export class AppInfoAdapter implements AppInfoPort {
  private cachedVersionName: string | undefined = undefined;
  private cachedVersionCode: number | undefined = undefined;

  versionName(): string {
    this.ensureBundleInfo();
    return this.cachedVersionName ?? '—';
  }

  versionCode(): number {
    this.ensureBundleInfo();
    return this.cachedVersionCode ?? 0;
  }

  versionLabel(): string {
    const name = this.versionName();
    const code = this.versionCode();
    return code > 0 ? `${name} (${code})` : name;
  }

  deviceType(): string {
    try {
      const value = deviceInfo.deviceType.trim();
      return value.length > 0 ? value : 'unknown';
    } catch (_error) {
      return 'unknown';
    }
  }

  osLabel(): string {
    try {
      const distName = deviceInfo.distributionOSName.trim();
      const distVer = deviceInfo.distributionOSVersion.trim();
      const api = deviceInfo.sdkApiVersion;
      if (distName.length > 0 || distVer.length > 0) {
        const prefix = `${distName} ${distVer}`.trim();
        return api > 0 ? `${prefix} (API ${api})` : prefix;
      }
      const fullName = deviceInfo.osFullName.trim();
      if (fullName.length > 0) {
        return api > 0 ? `${fullName} (API ${api})` : fullName;
      }
      return api > 0 ? `HarmonyOS (API ${api})` : 'HarmonyOS';
    } catch (_error) {
      return 'HarmonyOS';
    }
  }

  private ensureBundleInfo(): void {
    if (this.cachedVersionName !== undefined && this.cachedVersionCode !== undefined) {
      return;
    }

    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
      );
      this.cachedVersionName = bundleInfo.versionName;
      this.cachedVersionCode = bundleInfo.versionCode;
    } catch (error) {
      const businessError = error as BusinessError;
      console.error(`Read application version failed. Code: ${businessError.code}, message: ${businessError.message}`);
      // A bundle-manager failure can be transient during Ability startup.
      // Return a display fallback for this call, but do not memoize the
      // failure so a later render can retry the platform query.
    }
  }
}