/**
 * 3D asset metadata deliberately contains no ArkUI or ArkGraphics objects.
 *
 * The product renderer consumes this manifest and owns the native Scene
 * lifetime. Keeping the manifest serializable makes it possible to add an
 * on-demand downloader later without changing the article route or viewer
 * contract.
 */
export const SCP_3D_ASSET_SCHEMA_VERSION: number = 3;

export enum Scp3DAssetFormat {
  GLTF = 'gltf',
  GLB = 'glb'
}

/** Where the reviewed source came from. */
export enum Scp3DAssetSource {
  BUNDLED = 'bundled',
  /** The bytes are fetched into the app-private archive cache on demand. */
  REMOTE = 'remote'
}

/** How the app delivers the bytes to the viewer. */
export enum Scp3DAssetDelivery {
  BUNDLED = 'bundled',
  ON_DEMAND = 'on_demand'
}

export enum Scp3DAssetKind {
  SPECIFIC = 'specific',
  GENERIC = 'generic'
}

/** Build-time manifest row; it never contains a native Scene handle. */
export interface Scp3DAssetManifestEntry {
  readonly assetId: string;
  readonly contentId: string;
  readonly resourcePath: string;
  readonly format: Scp3DAssetFormat;
  readonly source: Scp3DAssetSource;
  readonly delivery: Scp3DAssetDelivery;
  readonly version: string;
  readonly byteLength: number;
  readonly sha256: string;
  readonly license: string;
  readonly licenseUrl: string;
  readonly attribution: string;
  readonly contentAttribution: string;
  readonly sourceLabel: string;
  readonly sourceUrl: string;
  /** HTTPS object URL used by the runtime downloader; empty for bundled rows. */
  readonly downloadUrl: string;
  readonly contentSourceUrl: string;
  readonly description: string;
  readonly objectClass: string;
  /** A short, item-specific licensing or representation notice. */
  readonly notice: string;
  /** Processing performed before the binary was shipped in the app. */
  readonly modificationNote: string;
  /** Renderer budget metadata; it is not a runtime graphics object. */
  readonly estimatedTriangleCount: number;
  readonly renderTargetMaxPx: number;
  readonly cameraDistance: number;
  readonly fieldOfView: number;
  readonly initialScale: number;
  readonly minimumScale: number;
  readonly maximumScale: number;
  /** Named source clip and normalized sample point used for a natural pose. */
  readonly poseAnimationName: string;
  readonly poseSampleRatio: number;
  /** Root correction for raw upstream exports (does not mutate downloaded bytes). */
  readonly runtimeScale: number;
  readonly runtimeOffsetX: number;
  readonly runtimeOffsetY: number;
  readonly runtimeOffsetZ: number;
  readonly hasExternalDependencies: boolean;
  readonly isConceptual: boolean;
}

/**
 * An item-bound asset descriptor. The same immutable asset can be rendered for
 * one canonical SCP page while `itemId` keeps the page identity explicit in
 * analytics and future cache keys.
 */
export class Scp3DModelAsset {
  readonly schemaVersion: number;
  readonly assetId: string;
  readonly itemId: string;
  readonly title: string;
  readonly kind: Scp3DAssetKind;
  readonly resourcePath: string;
  readonly format: Scp3DAssetFormat;
  readonly source: Scp3DAssetSource;
  readonly delivery: Scp3DAssetDelivery;
  readonly version: string;
  readonly byteLength: number;
  readonly sha256: string;
  readonly license: string;
  readonly licenseUrl: string;
  readonly attribution: string;
  readonly contentAttribution: string;
  readonly sourceLabel: string;
  readonly sourceUrl: string;
  readonly downloadUrl: string;
  readonly contentSourceUrl: string;
  readonly description: string;
  readonly objectClass: string;
  readonly notice: string;
  readonly modificationNote: string;
  readonly estimatedTriangleCount: number;
  readonly renderTargetMaxPx: number;
  readonly cameraDistance: number;
  readonly fieldOfView: number;
  readonly initialScale: number;
  readonly minimumScale: number;
  readonly maximumScale: number;
  readonly poseAnimationName: string;
  readonly poseSampleRatio: number;
  readonly runtimeScale: number;
  readonly runtimeOffsetX: number;
  readonly runtimeOffsetY: number;
  readonly runtimeOffsetZ: number;
  readonly hasExternalDependencies: boolean;
  readonly isConceptual: boolean;

  constructor(
    itemId: string,
    title: string,
    manifest: Scp3DAssetManifestEntry,
    kind: Scp3DAssetKind = Scp3DAssetKind.SPECIFIC
  ) {
    this.schemaVersion = SCP_3D_ASSET_SCHEMA_VERSION;
    this.assetId = manifest.assetId;
    this.itemId = itemId;
    this.title = title;
    this.kind = kind;
    this.resourcePath = manifest.resourcePath;
    this.format = manifest.format;
    this.source = manifest.source;
    this.delivery = manifest.delivery;
    this.version = manifest.version;
    this.byteLength = manifest.byteLength;
    this.sha256 = manifest.sha256;
    this.license = manifest.license;
    this.licenseUrl = manifest.licenseUrl;
    this.attribution = manifest.attribution;
    this.contentAttribution = manifest.contentAttribution;
    this.sourceLabel = manifest.sourceLabel;
    this.sourceUrl = manifest.sourceUrl;
    this.downloadUrl = manifest.downloadUrl.trim();
    this.contentSourceUrl = manifest.contentSourceUrl;
    this.description = manifest.description;
    this.objectClass = manifest.objectClass;
    this.notice = manifest.notice;
    this.modificationNote = manifest.modificationNote;
    this.estimatedTriangleCount = manifest.estimatedTriangleCount;
    this.renderTargetMaxPx = manifest.renderTargetMaxPx;
    this.cameraDistance = manifest.cameraDistance;
    this.fieldOfView = manifest.fieldOfView;
    this.initialScale = manifest.initialScale;
    this.minimumScale = manifest.minimumScale;
    this.maximumScale = manifest.maximumScale;
    this.poseAnimationName = manifest.poseAnimationName.trim();
    this.poseSampleRatio = Number.isFinite(manifest.poseSampleRatio) ?
      Math.max(0, Math.min(1, manifest.poseSampleRatio)) : 0.5;
    this.runtimeScale = Number.isFinite(manifest.runtimeScale) && manifest.runtimeScale > 0 ?
      manifest.runtimeScale : 1;
    this.runtimeOffsetX = Number.isFinite(manifest.runtimeOffsetX) ? manifest.runtimeOffsetX : 0;
    this.runtimeOffsetY = Number.isFinite(manifest.runtimeOffsetY) ? manifest.runtimeOffsetY : 0;
    this.runtimeOffsetZ = Number.isFinite(manifest.runtimeOffsetZ) ? manifest.runtimeOffsetZ : 0;
    this.hasExternalDependencies = manifest.hasExternalDependencies;
    this.isConceptual = manifest.isConceptual;
  }
}

const SOURCE_REPOSITORY: string = 'https://github.com/Yni-Viar/scp-unity-assets';
const SOURCE_COMMIT: string = '7fda38944f51db7ee3aeb4d9e5ca821263153da5';
const SCP_ASSETS_REPOSITORY: string = 'https://github.com/Yni-Viar/scp-assets';
// Pin the on-demand sources to a commit instead of a moving branch. This
// keeps the download URL, byte length and SHA-256 review reproducible.
const SCP_ASSETS_COMMIT: string = '1265487d1978b60398ab71f366bc5a1ba4ce1d0d';
const CC_BY_SA_3_URL: string = 'https://creativecommons.org/licenses/by-sa/3.0/';
const MOBILE_PROCESSING_NOTICE: string =
  '已针对移动端精简：定格静态观察姿态、压缩贴图尺寸并移除冗余动画。';
const REMOTE_RUNTIME_NOTICE: string =
  '使用原始模型文件，加载时自动居中并适配观测比例，不改写源文件。';
const REPRESENTATION_NOTICE: string =
  '本模型由社区创作者制作，仅供外观参考，并非基金会官方设定形象。';

function sourceUrl(folder: string, fileName: string): string {
  return `${SOURCE_REPOSITORY}/blob/${SOURCE_COMMIT}/Rigged-Ready/${folder}/${fileName}.glb`;
}

function rawSourceUrl(folder: string, fileName: string): string {
  return `https://raw.githubusercontent.com/Yni-Viar/scp-unity-assets/${SOURCE_COMMIT}/Rigged-Ready/${folder}/${fileName}.glb`;
}

function scpAssetsSourceUrl(path: string): string {
  return `${SCP_ASSETS_REPOSITORY}/blob/${SCP_ASSETS_COMMIT}/${path}`;
}

function scpAssetsRawUrl(path: string): string {
  return `https://raw.githubusercontent.com/Yni-Viar/scp-assets/${SCP_ASSETS_COMMIT}/${path}`;
}

/**
 * Reviewed seed models. Every row in this list exposes a 三维档案 action;
 * delivery only controls whether the bytes are bundled or installed on demand.
 * An unknown SCP number never falls back to a generic placeholder.
 */
export const SCP_3D_ASSET_MANIFEST: Scp3DAssetManifestEntry[] = [
  {
    assetId: 'scp-106-mobile-v1',
    contentId: 'scp-106',
    resourcePath: 'models/scp-106.glb',
    format: Scp3DAssetFormat.GLB,
    source: Scp3DAssetSource.BUNDLED,
    delivery: Scp3DAssetDelivery.BUNDLED,
    version: '1.0.0-mobile-pose',
    byteLength: 8662380,
    sha256: 'b4141e5b4ca03cce7da388a28d0d18d25a8dbb9d88545e79028ebd965fd0d23b',
    license: 'CC BY-SA 3.0',
    licenseUrl: CC_BY_SA_3_URL,
    attribution: 'Aruspice（模型/贴图）、Shakles（绑定/动画）、PixelPuffin（概念设计）',
    contentAttribution: '条目来源：SCP Wiki / SCP-106',
    sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp106',
    sourceUrl: sourceUrl('Scp106', 'Scp106'),
    downloadUrl: '',
    contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-106',
    description: '腐朽人形实体外观模型，体表呈焦黑蚀损状，供形态特征观察。',
    objectClass: 'KETER',
    notice: REPRESENTATION_NOTICE,
    modificationNote: MOBILE_PROCESSING_NOTICE,
    estimatedTriangleCount: 16404,
    renderTargetMaxPx: 768,
    cameraDistance: 6.8,
    fieldOfView: 0.56,
    initialScale: 1.05,
    minimumScale: 0.62,
    maximumScale: 1.72,
    poseAnimationName: '106_Idle',
    poseSampleRatio: 0.5,
    runtimeScale: 1,
    runtimeOffsetX: 0,
    runtimeOffsetY: 0,
    runtimeOffsetZ: 0,
    hasExternalDependencies: false,
    isConceptual: true
  },
  {
    assetId: 'scp-049-mobile-v2',
    contentId: 'scp-049',
    resourcePath: 'models/scp-049.glb',
    format: Scp3DAssetFormat.GLB,
    source: Scp3DAssetSource.BUNDLED,
    delivery: Scp3DAssetDelivery.BUNDLED,
    version: '2.1.0-mobile-pose',
    byteLength: 6947368,
    sha256: '7d9fd347d38e67ed2e3b8465b62d27674cacfeeb15c4e31b953fef19e97ef962',
    license: 'CC BY-SA 3.0',
    licenseUrl: CC_BY_SA_3_URL,
    attribution: 'Aruspice（模型/贴图）、Shakles（绑定/动画）、PixelPuffin（概念设计）',
    contentAttribution: '条目作者：Gabriel Jade；重写：djkaktus、Gabriel Jade',
    sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp049',
    sourceUrl: sourceUrl('Scp049', 'Scp049'),
    downloadUrl: '',
    contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-049',
    description: '鸟嘴面具与黑袍人形实体模型，呈现档案记载的“疫医”外观。',
    objectClass: 'EUCLID',
    notice: REPRESENTATION_NOTICE,
    modificationNote: MOBILE_PROCESSING_NOTICE,
    estimatedTriangleCount: 12720,
    renderTargetMaxPx: 768,
    cameraDistance: 6.8,
    fieldOfView: 0.56,
    initialScale: 1.09,
    minimumScale: 0.66,
    maximumScale: 1.75,
    poseAnimationName: '049_Idle2',
    poseSampleRatio: 0.5,
    runtimeScale: 1,
    runtimeOffsetX: 0,
    runtimeOffsetY: 0,
    runtimeOffsetZ: 0,
    hasExternalDependencies: false,
    isConceptual: true
  },
  {
    assetId: 'scp-173-mobile-v2',
    contentId: 'scp-173',
    resourcePath: 'models/scp-173.glb',
    format: Scp3DAssetFormat.GLB,
    source: Scp3DAssetSource.BUNDLED,
    delivery: Scp3DAssetDelivery.BUNDLED,
    version: '2.1.0-mobile-pose',
    byteLength: 3969944,
    sha256: 'f89aefe1f7cf116dc8c12e9c5d554278217afe4744e49e14ab52840ca91f256d',
    license: 'CC BY-SA 3.0',
    licenseUrl: CC_BY_SA_3_URL,
    attribution: 'Aruspice（模型/贴图）、Shakles（绑定/动画）、PixelPuffin（概念设计）',
    contentAttribution: '条目作者：Moto42',
    sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp173',
    sourceUrl: sourceUrl('Scp173', 'Scp173'),
    downloadUrl: '',
    contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-173',
    description: '混凝土与钢筋雕像重制版外观模型，定格于受注视时的静止形态。',
    objectClass: 'EUCLID',
    notice: `${REPRESENTATION_NOTICE} 采用社区重制外观，未使用原版《无题2004》雕塑形象。`,
    modificationNote: MOBILE_PROCESSING_NOTICE,
    estimatedTriangleCount: 16104,
    renderTargetMaxPx: 768,
    cameraDistance: 6.8,
    fieldOfView: 0.56,
    initialScale: 1.04,
    minimumScale: 0.62,
    maximumScale: 1.62,
    poseAnimationName: '173_Pose1',
    poseSampleRatio: 0,
    runtimeScale: 1,
    runtimeOffsetX: 0,
    runtimeOffsetY: 0,
    runtimeOffsetZ: 0,
    hasExternalDependencies: false,
    isConceptual: true
  },
  {
    assetId: 'scp-939-mobile-v2',
    contentId: 'scp-939',
    resourcePath: 'models/scp-939.glb',
    format: Scp3DAssetFormat.GLB,
    source: Scp3DAssetSource.BUNDLED,
    delivery: Scp3DAssetDelivery.BUNDLED,
    version: '2.1.0-mobile-pose',
    byteLength: 3209604,
    sha256: 'cd243a640bcba5379609957ebb94beea3c31c2bd8a6e7e8a53e605abe4a33767',
    license: 'CC BY-SA 3.0',
    licenseUrl: CC_BY_SA_3_URL,
    attribution: 'Apocryphos（模型）、Shadowscale（贴图）、Shakles（绑定/动画）',
    contentAttribution: '条目作者：Adam Smascher、EchoFourDelta',
    sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp939',
    sourceUrl: sourceUrl('Scp939', 'Scp939'),
    downloadUrl: '',
    contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-939',
    description: '无眼、暗红表皮的掠食实体模型，呈现其低伏体态与头颌轮廓。',
    objectClass: 'KETER',
    notice: REPRESENTATION_NOTICE,
    modificationNote: MOBILE_PROCESSING_NOTICE,
    estimatedTriangleCount: 10368,
    renderTargetMaxPx: 768,
    cameraDistance: 6.8,
    fieldOfView: 0.56,
    initialScale: 1.32,
    minimumScale: 0.79,
    maximumScale: 2.11,
    poseAnimationName: '939_Idle',
    poseSampleRatio: 0.5,
    runtimeScale: 1,
    runtimeOffsetX: 0,
    runtimeOffsetY: 0,
    runtimeOffsetZ: 0,
    hasExternalDependencies: false,
    isConceptual: true
  },
  {
    assetId: 'scp-131-orange-mobile-v1',
    contentId: 'scp-131',
    resourcePath: '',
    format: Scp3DAssetFormat.GLB,
    source: Scp3DAssetSource.REMOTE,
    delivery: Scp3DAssetDelivery.ON_DEMAND,
    version: '1.0.0-upstream',
    byteLength: 12429448,
    sha256: '5e01d45bcb75bff4465f3b6418169919ea35ece79346e0e540d085b704a0a32a',
    license: 'CC BY-SA 3.0',
    licenseUrl: CC_BY_SA_3_URL,
    attribution: 'Aruspice（模型/贴图）、Shakles（绑定/动画）',
    contentAttribution: '条目作者：Lt Masipag；SCP-131-A 橙色成员',
    sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp131/Scp131Orange',
    sourceUrl: sourceUrl('Scp131', 'Scp131Orange'),
    downloadUrl: rawSourceUrl('Scp131', 'Scp131Orange'),
    contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-131',
    description: '橙色“眼豆”个体 SCP-131-A 模型，呈泪滴状单眼形态（当前仅收录 A 号个体）。',
    objectClass: 'SAFE',
    notice: `${REPRESENTATION_NOTICE} 当前档案仅收录橙色个体 SCP-131-A。`,
    modificationNote: REMOTE_RUNTIME_NOTICE,
    estimatedTriangleCount: 4104,
    renderTargetMaxPx: 768,
    cameraDistance: 4.8,
    fieldOfView: 0.56,
    initialScale: 10.8,
    minimumScale: 6.5,
    maximumScale: 17.5,
    poseAnimationName: '131_Idle',
    poseSampleRatio: 0.5,
    // The source already carries its authored 0.01 skeleton scale.  The
    // viewer's established 10.8 framing compensates for that scale; applying
    // another 12x correction here would make the object roughly an order of
    // magnitude too large. Keep this correction neutral until a reviewed
    // composite export replaces the raw on-demand source.
    runtimeScale: 1,
    runtimeOffsetX: 0,
    runtimeOffsetY: -0.1175352839,
    runtimeOffsetZ: -0.0068236999,
    hasExternalDependencies: false,
    isConceptual: true
  },
  {
    assetId: 'scp-3199-mobile-v1',
    contentId: 'scp-3199',
    resourcePath: '',
    format: Scp3DAssetFormat.GLB,
    source: Scp3DAssetSource.REMOTE,
    delivery: Scp3DAssetDelivery.ON_DEMAND,
    version: '1.0.0-upstream',
    byteLength: 51054324,
    sha256: 'c83d9cf29b7282827c94924e1ccd6983c8c94a175b1e0df9a9d7a7e9a76800e1',
    license: 'CC BY-SA 3.0',
    licenseUrl: CC_BY_SA_3_URL,
    attribution: 'Aruspice（模型/贴图）、Shakles（绑定/动画）',
    contentAttribution: '条目来源：SCP Wiki / SCP-3199',
    sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp3199',
    sourceUrl: sourceUrl('Scp3199', 'Scp3199'),
    downloadUrl: rawSourceUrl('Scp3199', 'Scp3199'),
    contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-3199',
    description: '无毛类禽人形实体模型，呈现长颈、垂颌与鸟类肢体等典型解剖特征。',
    objectClass: 'KETER',
    notice: REPRESENTATION_NOTICE,
    modificationNote: REMOTE_RUNTIME_NOTICE,
    estimatedTriangleCount: 16002,
    renderTargetMaxPx: 768,
    cameraDistance: 6.8,
    fieldOfView: 0.56,
    initialScale: 1.03,
    minimumScale: 0.62,
    maximumScale: 1.72,
    poseAnimationName: '3199_Idle',
    poseSampleRatio: 0.5,
    runtimeScale: 1,
    runtimeOffsetX: 0,
    runtimeOffsetY: -1.4218896031,
    runtimeOffsetZ: 0.1055011749,
    hasExternalDependencies: false,
    isConceptual: true
  },
  {
    assetId: 'scp-650-mobile-v1',
    contentId: 'scp-650',
    resourcePath: '',
    format: Scp3DAssetFormat.GLB,
    source: Scp3DAssetSource.REMOTE,
    delivery: Scp3DAssetDelivery.ON_DEMAND,
    version: '1.0.0-upstream',
    byteLength: 8180984,
    sha256: '62bf92f0cd131fc0f71268a264c79eb02b9387c360dc60fe88c89226c5620c44',
    license: 'CC BY-SA 3.0',
    licenseUrl: CC_BY_SA_3_URL,
    attribution: 'Shadowscale（模型/贴图）',
    contentAttribution: '条目作者：Dr Talson',
    sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp650',
    sourceUrl: sourceUrl('Scp650', 'Scp650'),
    downloadUrl: rawSourceUrl('Scp650', 'Scp650'),
    contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-650',
    description: '通体漆黑的无面人形雕像模型，定格于直视观测下的静止姿态。',
    objectClass: 'EUCLID',
    notice: REPRESENTATION_NOTICE,
    modificationNote: REMOTE_RUNTIME_NOTICE,
    estimatedTriangleCount: 8640,
    renderTargetMaxPx: 768,
    cameraDistance: 6.8,
    fieldOfView: 0.56,
    initialScale: 1.19,
    minimumScale: 0.71,
    maximumScale: 1.90,
    // The source's Default clip is identical to its authored neutral stance.
    // Keep animations disabled at runtime: this avoids evaluating an idle
    // skeleton for a still archive object and gives the framing correction a
    // deterministic reference pose.
    poseAnimationName: '',
    poseSampleRatio: 0,
    runtimeScale: 1,
    runtimeOffsetX: 0.09020066,
    runtimeOffsetY: -1.04469753,
    runtimeOffsetZ: -0.00523740,
    hasExternalDependencies: false,
    isConceptual: true
  },
  {
    assetId: 'scp-079-cb-v1',
    contentId: 'scp-079',
    resourcePath: '',
    format: Scp3DAssetFormat.GLB,
    source: Scp3DAssetSource.REMOTE,
    delivery: Scp3DAssetDelivery.ON_DEMAND,
    version: '1.0.0-upstream',
    byteLength: 2771372,
    sha256: '6cd62bd301387cfbedaa848c93fbad06cab8c1730702816a94e88b34593a5e83',
    license: 'CC BY-SA 3.0',
    licenseUrl: CC_BY_SA_3_URL,
    attribution: 'Hakkla（模型/贴图）、Yni（重混）',
    contentAttribution: '条目来源：SCP Wiki / SCP-079',
    sourceLabel: 'Yni-Viar/scp-assets · GFX/SCP-CB/EditedByYni/scp079/079',
    sourceUrl: scpAssetsSourceUrl('GFX/SCP-CB/EditedByYni/scp079/079/Scp079.glb'),
    downloadUrl: scpAssetsRawUrl('GFX/SCP-CB/EditedByYni/scp079/079/Scp079.glb'),
    contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-079',
    description: '1978 年 Exidy Sorcerer 微型计算机与黑白显示器外观模型，呈现旧式终端硬件全貌。',
    objectClass: 'EUCLID',
    notice: REPRESENTATION_NOTICE,
    modificationNote: REMOTE_RUNTIME_NOTICE,
    estimatedTriangleCount: 13228,
    renderTargetMaxPx: 768,
    cameraDistance: 6.8,
    fieldOfView: 0.56,
    // The source is a compact horizontal computer assembly. Size it by its
    // width so the portrait stage does not crop the peripherals.
    initialScale: 4.8,
    minimumScale: 2.8,
    maximumScale: 7.2,
    poseAnimationName: '',
    poseSampleRatio: 0,
    runtimeScale: 1,
    runtimeOffsetX: -0.00010730,
    runtimeOffsetY: -0.09792394,
    runtimeOffsetZ: -0.00006816,
    hasExternalDependencies: false,
    isConceptual: true
  },
  {
    assetId: 'scp-178-cb-v1',
    contentId: 'scp-178',
    resourcePath: '',
    format: Scp3DAssetFormat.GLB,
    source: Scp3DAssetSource.REMOTE,
    delivery: Scp3DAssetDelivery.ON_DEMAND,
    version: '1.0.0-upstream',
    byteLength: 2330788,
    sha256: '9a2eb124b43470a8208c1235d52a528c9be1ced0c4c2fa509a06e57bbbc62f1e',
    license: 'CC BY-SA 3.0',
    licenseUrl: CC_BY_SA_3_URL,
    attribution: 'Kenneth crooker（模型）',
    contentAttribution: '条目来源：SCP Wiki / SCP-178',
    sourceLabel: 'Yni-Viar/scp-assets · GFX/SCP-CB/Characters/Scp178-1',
    sourceUrl: scpAssetsSourceUrl('GFX/SCP-CB/Characters/Scp178-1/Scp178-1.glb'),
    downloadUrl: scpAssetsRawUrl('GFX/SCP-CB/Characters/Scp178-1/Scp178-1.glb'),
    contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-178',
    description: '立体眼镜关联实体 SCP-178-1 外观模型，还原佩戴者视野中的双足怪异形体。',
    objectClass: 'SAFE',
    notice: REPRESENTATION_NOTICE,
    modificationNote: REMOTE_RUNTIME_NOTICE,
    estimatedTriangleCount: 27958,
    renderTargetMaxPx: 768,
    cameraDistance: 6.8,
    fieldOfView: 0.56,
    initialScale: 1.12,
    minimumScale: 0.68,
    maximumScale: 1.82,
    // The source character is exported roughly 25x larger than the viewer's
    // unit convention. Scale the authored hierarchy before applying the
    // measured visible-bounds correction; this keeps the pivot centered.
    // Offsets are authored-space values because the correction node is below
    // the scale root. Supplying already-scaled values here would scale them a
    // second time and leave the character above the portrait stage.
    poseAnimationName: '',
    poseSampleRatio: 0,
    runtimeScale: 0.04,
    runtimeOffsetX: 0.88417149,
    runtimeOffsetY: -35.96007232,
    runtimeOffsetZ: 2.26652622,
    hasExternalDependencies: false,
    isConceptual: true
  },
  {
    assetId: 'scp-686-icard-v1',
    contentId: 'scp-686',
    resourcePath: '',
    format: Scp3DAssetFormat.GLB,
    source: Scp3DAssetSource.REMOTE,
    delivery: Scp3DAssetDelivery.ON_DEMAND,
    version: '1.0.0-upstream',
    byteLength: 129020,
    sha256: '2b90bc9eb186054dc8ed6200a1195b9444c526460ba4699baead9def1cb8f207',
    license: 'CC BY-SA 3.0',
    licenseUrl: CC_BY_SA_3_URL,
    attribution: 'pop_pop_icard（模型）',
    contentAttribution: '条目来源：SCP Wiki / SCP-686',
    sourceLabel: 'Yni-Viar/scp-assets · GFX/By_Pop_Pop_Icard/Items/Scp686',
    sourceUrl: scpAssetsSourceUrl('GFX/By_Pop_Pop_Icard/Items/Scp686/Scp686.glb'),
    downloadUrl: scpAssetsRawUrl('GFX/By_Pop_Pop_Icard/Items/Scp686/Scp686.glb'),
    contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-686',
    description: '盛装异常乳白色液体的玻璃瓶模型，呈现收容容器的外部形态。',
    objectClass: 'SAFE',
    notice: REPRESENTATION_NOTICE,
    modificationNote: REMOTE_RUNTIME_NOTICE,
    estimatedTriangleCount: 2242,
    renderTargetMaxPx: 768,
    cameraDistance: 6.8,
    fieldOfView: 0.56,
    initialScale: 8.8,
    minimumScale: 5.0,
    maximumScale: 13.0,
    poseAnimationName: '',
    poseSampleRatio: 0,
    runtimeScale: 1,
    runtimeOffsetX: -0.00497,
    runtimeOffsetY: -0.06063,
    runtimeOffsetZ: 0.00283,
    hasExternalDependencies: false,
    isConceptual: true
  }
];

/**
 * Delivery policy guardrail: only the small, reviewed classic seed set may
 * become part of the application package.  SCP-096 is intentionally listed
 * here as an allowed classic id so a future reviewed asset can be bundled,
 * but it is not a manifest row until its binary provenance is approved.
 */
const CLASSIC_BUNDLED_CONTENT_IDS: string[] = [
  'scp-049',
  'scp-106',
  'scp-173',
  'scp-939',
  'scp-096'
];

function validateDeliveryPolicy(entry: Scp3DAssetManifestEntry): void {
  const isClassic = CLASSIC_BUNDLED_CONTENT_IDS.indexOf(entry.contentId) >= 0;
  if (entry.delivery === Scp3DAssetDelivery.BUNDLED && !isClassic) {
    throw new Error(`非经典 SCP 不得随应用内置：${entry.contentId}`);
  }
  if (entry.delivery === Scp3DAssetDelivery.BUNDLED &&
    entry.source !== Scp3DAssetSource.BUNDLED) {
    throw new Error(`内置模型来源标记不一致：${entry.contentId}`);
  }
  if (entry.delivery === Scp3DAssetDelivery.ON_DEMAND &&
    (entry.source !== Scp3DAssetSource.REMOTE || !entry.downloadUrl.startsWith('https://'))) {
    throw new Error(`按需模型必须声明 HTTPS 远程来源：${entry.contentId}`);
  }
}

for (let index: number = 0; index < SCP_3D_ASSET_MANIFEST.length; index++) {
  validateDeliveryPolicy(SCP_3D_ASSET_MANIFEST[index]);
}

/** Normalize and validate an SCP object id at the feature boundary. */
export function normalizeScpObjectId(value: string): string | undefined {
  let normalized = value.trim().toLowerCase();
  while (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  if (normalized.length === 0 || normalized.length > 68 ||
    !/^scp-[a-z0-9][a-z0-9_-]{0,63}$/.test(normalized)) {
    return undefined;
  }
  return normalized;
}

function boundedTitle(title: string, fallback: string): string {
  const trimmed = title.trim();
  if (trimmed.length === 0) {
    return fallback;
  }
  return trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed;
}

/** Find a reviewed catalog row, regardless of how its bytes are delivered. */
function findManifestEntry(normalizedId: string): Scp3DAssetManifestEntry | undefined {
  for (let index: number = 0; index < SCP_3D_ASSET_MANIFEST.length; index++) {
    const candidate = SCP_3D_ASSET_MANIFEST[index];
    if (candidate.contentId === normalizedId) {
      return candidate;
    }
  }
  return undefined;
}

/** True for SCP object ids with a reviewed catalog row (bundled or on-demand). */
export function hasScp3DModel(itemId: string): boolean {
  const normalized = normalizeScpObjectId(itemId);
  return normalized !== undefined && findManifestEntry(normalized) !== undefined;
}

/** Resolve only reviewed catalog rows; no network URL or generic fallback is inferred. */
export function resolveScp3DModelAsset(
  itemId: string,
  title: string = ''
): Scp3DModelAsset | undefined {
  const normalized = normalizeScpObjectId(itemId);
  if (normalized === undefined) {
    return undefined;
  }
  const manifest = findManifestEntry(normalized);
  if (manifest === undefined) {
    return undefined;
  }
  return new Scp3DModelAsset(
    normalized,
    boundedTitle(title, normalized.toUpperCase()),
    manifest,
    Scp3DAssetKind.SPECIFIC
  );
}

/**
 * Project the immutable catalog into item-bound assets for the archive gallery.
 * The returned array is freshly allocated so callers cannot mutate the build
 * manifest or accidentally retain native rendering state in the HAR.
 */
export function listScp3DModelAssets(): Scp3DModelAsset[] {
  return SCP_3D_ASSET_MANIFEST.map((manifest: Scp3DAssetManifestEntry): Scp3DModelAsset =>
    new Scp3DModelAsset(
      manifest.contentId,
      manifest.contentId.toUpperCase(),
      manifest,
      Scp3DAssetKind.SPECIFIC
    )
  );
}
