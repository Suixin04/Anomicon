import { uiMaterial } from '@kit.ArkUI';
import { hdsMaterial, ScrollEffectType, TitleBarStyleOptions } from '@kit.UIDesignKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * Shared phone navigation tokens and capability adapter.
 *
 * Product and feature code share one status-bar/material state without
 * reaching into platform-specific navigation objects.
 */
const MATERIAL_DOMAIN = 0x0000;
const MATERIAL_TAG = 'AnomiconMaterial';

export const PHONE_PAGE_MARGIN: number = 16;
export const PHONE_TAB_CONTENT_MAX_WIDTH: number = 680;
export const PHONE_TAB_CONTENT_TOP_GAP: number = 12;
/** Scrollable tail reserved for the overlapping floating tab bar. */
export const PHONE_TAB_CONTENT_BOTTOM_SPACE: number = 160;
export const HDS_TITLE_BAR_HEIGHT_MINI: number = 56;
const FALLBACK_STATUS_BAR_HEIGHT: number = 60;

@ObservedV2
class NavigationTopInsetState {
  @Trace avoidTop: number = FALLBACK_STATUS_BAR_HEIGHT;
}

const navigationTopInset = new NavigationTopInsetState();

export function updateWindowAvoidArea(avoidTop: number): void {
  navigationTopInset.avoidTop = avoidTop;
}

/** Current top system avoid-area inset in vp (e.g., status bar height). */
export function windowAvoidTop(): number {
  return navigationTopInset.avoidTop;
}

/** Content top inset: system avoid area + floating MINI title bar. */
export function pageContentTop(): number {
  return navigationTopInset.avoidTop + HDS_TITLE_BAR_HEIGHT_MINI;
}

// Cache only a positive capability result. A transient false result can mean
// the system capability service is not ready yet, so query again next time.
let materialSupportCached: boolean = false;
let materialSupportQueried: boolean = false;

function supportsImmersiveMaterial(): boolean {
  if (materialSupportQueried && materialSupportCached) {
    return true;
  }
  try {
    const supportedTypes = hdsMaterial.getSystemMaterialTypes();
    const next = supportedTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;
    if (!materialSupportQueried || next !== materialSupportCached) {
      hilog.info(
        MATERIAL_DOMAIN,
        MATERIAL_TAG,
        'capability query: %{public}d types, immersive=%{public}s',
        supportedTypes.length,
        next ? 'true' : 'false'
      );
    }
    materialSupportQueried = true;
    materialSupportCached = next;
  } catch (error) {
    const businessError = error as BusinessError;
    hilog.error(
      MATERIAL_DOMAIN,
      MATERIAL_TAG,
      'capability query failed: %{public}d %{public}s',
      businessError.code,
      businessError.message
    );
    console.warn(`Query HDS material capability failed. Code: ${businessError.code}, message: ${businessError.message}`);
    materialSupportQueried = false;
  }
  return materialSupportCached;
}

export function immersiveMaterialSupported(): boolean {
  return supportsImmersiveMaterial();
}

let uiMaterialSupportCached: boolean = false;
let uiMaterialSupportQueried: boolean = false;

/** Query ArkUI ImmersiveMaterial capability, caching only a positive result. */
export function uiImmersiveMaterialSupported(): boolean {
  if (uiMaterialSupportQueried && uiMaterialSupportCached) {
    return true;
  }
  try {
    const supported = uiMaterial.isImmersiveMaterialSupported();
    uiMaterialSupportQueried = true;
    uiMaterialSupportCached = supported;
    return supported;
  } catch (error) {
    const businessError = error as BusinessError;
    console.warn(`Query UI immersive material capability failed. Code: ${businessError.code}, message: ${businessError.message}`);
    uiMaterialSupportQueried = false;
    return false;
  }
}

/** Build the shared title-bar style while hiding platform details from Views. */
export function createAppTitleBarStyle(materialEnabled: boolean = true): TitleBarStyleOptions {
  const immersiveSupported = materialEnabled && supportsImmersiveMaterial();
  return {
    scrollEffectOpts: {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
    },
    systemMaterialEffect: {
      materialType: immersiveSupported ?
        hdsMaterial.MaterialType.IMMERSIVE : hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    },
    originalStyle: {
      backgroundStyle: {
        backgroundColor: $r('sys.color.ohos_id_color_background_transparent')
      },
      contentStyle: {
        titleStyle: {
          mainTitleColor: $r('sys.color.font'),
          subTitleColor: $r('sys.color.font_secondary')
        },
        menuStyle: immersiveSupported ? {
          iconColor: $r('sys.color.icon')
        } : {
          backgroundColor: $r('sys.color.comp_background_secondary'),
          iconColor: $r('sys.color.icon')
        },
        backIconStyle: immersiveSupported ? {
          iconColor: $r('sys.color.icon')
        } : {
          backgroundColor: $r('sys.color.comp_background_secondary'),
          iconColor: $r('sys.color.icon')
        }
      }
    },
    scrollEffectStyle: {
      backgroundStyle: {
        backgroundColor: $r('app.color.navigation_bar_scroll_background')
      },
      contentStyle: {
        titleStyle: {
          mainTitleColor: $r('sys.color.font_on'),
          subTitleColor: $r('sys.color.font_on_secondary')
        },
        menuStyle: immersiveSupported ? {
          iconColor: $r('sys.color.icon_on')
        } : {
          backgroundColor: $r('sys.color.comp_background_secondary'),
          iconColor: $r('sys.color.icon_on')
        },
        backIconStyle: immersiveSupported ? {
          iconColor: $r('sys.color.icon_on')
        } : {
          backgroundColor: $r('sys.color.comp_background_secondary'),
          iconColor: $r('sys.color.icon_on')
        }
      }
    }
  };
}
