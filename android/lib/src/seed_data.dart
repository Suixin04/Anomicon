import 'models.dart';

class SeedData {
  static const _sourceRepository =
      'https://github.com/Yni-Viar/scp-unity-assets';
  static const _sourceCommit = '7fda38944f51db7ee3aeb4d9e5ca821263153da5';
  static const _assetsRepository = 'https://github.com/Yni-Viar/scp-assets';
  static const _assetsCommit = '1265487d1978b60398ab71f366bc5a1ba4ce1d0d';
  static const _ccBySa30 = 'CC BY-SA 3.0';
  static const _representationNotice = '社区创作的视觉重建，不代表 SCP 官方形象或实体复原。';
  static const _bundledRuntimeNotice = '已针对移动端精简并内置：定格观察姿态、压缩贴图并移除冗余动画。';
  static const _remoteRuntimeNotice = '下载并校验上游原始 GLB 文件。查看器自动适配取景比例，源文件保持不变。';

  static final fallbackCatalog = <CatalogEntry>[
    const CatalogEntry(
      itemId: 'SCP-001',
      title: '等待解密',
      description: '在管理员的命令下，此文档已被列为最高机密通用说明 001-Alpha。',
    ),
    const CatalogEntry(
      itemId: 'SCP-002',
      title: '“生活”室',
      description: '外形像一个体积约 60m3 的肉瘤，内部呈现公寓式房间。',
    ),
    const CatalogEntry(
      itemId: 'SCP-003',
      title: '生物母版',
      description: '由两块相关但不同源的组件组成，分别记作 SCP-003-1 与 SCP-003-2。',
    ),
    const CatalogEntry(
      itemId: 'SCP-004',
      title: '穿越锈钥之门',
      description: '一扇旧木质仓库门及一组共计 12 把生锈钥匙。',
    ),
    const CatalogEntry(
      itemId: 'SCP-005',
      title: '万能钥匙',
      description: '一把装饰华丽的钥匙，可打开大多数锁具。',
    ),
    const CatalogEntry(itemId: 'SCP-049', title: '瘟疫医生', hasArchive3D: true),
    const CatalogEntry(itemId: 'SCP-079', title: '旧 AI', hasArchive3D: true),
    const CatalogEntry(itemId: 'SCP-096', title: '羞涩的人'),
    const CatalogEntry(itemId: 'SCP-106', title: '恐怖老人', hasArchive3D: true),
    const CatalogEntry(itemId: 'SCP-131', title: '眼豆', hasArchive3D: true),
    const CatalogEntry(itemId: 'SCP-173', title: '雕像', hasArchive3D: true),
    const CatalogEntry(itemId: 'SCP-178', title: '三维眼镜', hasArchive3D: true),
    const CatalogEntry(itemId: 'SCP-650', title: '惊吓雕像', hasArchive3D: true),
    const CatalogEntry(itemId: 'SCP-686', title: '传染性液体容器', hasArchive3D: true),
    const CatalogEntry(itemId: 'SCP-939', title: '千喉之兽', hasArchive3D: true),
    const CatalogEntry(itemId: 'SCP-3199', title: '人类，反驳！', hasArchive3D: true),
  ];

  static const fallbackTales = <TaleEntry>[
    TaleEntry(id: '0-underture', title: '下界序曲'),
    TaleEntry(id: '0-unsinkable', title: '永不沉没'),
    TaleEntry(id: '049-x-minion-x-reader', title: '049 x 小兵 x 读者（读者是个小黄人）'),
    TaleEntry(id: '085-romance-adult', title: '085成人浪漫'),
    TaleEntry(id: '1-001-dark-and-stormy-nights', title: '1 001 黑暗暴风雨之夜'),
    TaleEntry(id: '1-hachiro', title: '1. Hachiro'),
    TaleEntry(id: '1-mr-headless', title: '1. 無頭先生'),
    TaleEntry(id: '1-remember-remember', title: '莫忘记，莫忘记……'),
    TaleEntry(id: '10-30-a-m', title: '上午十点半'),
    TaleEntry(id: 'about-the-foundation', title: '关于基金会'),
    TaleEntry(id: 'document-recovered-from-the-marianas-trench', title: '自马里亚纳海沟回收的文件'),
    TaleEntry(id: 'incident-096-1-a', title: '事故 096-1-A'),
  ];

  static const fallbackExplore = <ExploreEntry>[
    ExploreEntry(id: 'scp-cn-2000', title: 'SCP-CN-2000', score: 5521, summary: 'SCP 中文主站高分内容'),
    ExploreEntry(id: 'scp-cn-963-j', title: 'SCP-CN-963-J', score: 4505, summary: 'SCP 中文主站高分内容'),
    ExploreEntry(id: 'scp-cn-1109', title: 'SCP-CN-1109', score: 3619, summary: 'SCP 中文主站高分内容'),
    ExploreEntry(id: 'scp-173', title: 'SCP-173 - 雕像', score: 3200, summary: '经典主站档案'),
    ExploreEntry(id: 'scp-049', title: 'SCP-049 - 瘟疫医生', score: 2900, summary: '经典主站档案'),
    ExploreEntry(id: 'scp-106', title: 'SCP-106 - 恐怖老人', score: 2600, summary: '经典主站档案'),
  ];

  static const fallbackRecommendations = <ExploreEntry>[
    ExploreEntry(
      id: 'scp-6551',
      title: 'SCP-6551',
      summary: 'SCP-6551 是一件经过改造的普通物体档案。每天随机解析一组主站档案。',
    ),
    ExploreEntry(id: 'scp-049', title: 'SCP-049', summary: '瘟疫医生形象的经典档案。'),
    ExploreEntry(id: 'scp-106', title: 'SCP-106', summary: '腐蚀性实体的经典档案。'),
    ExploreEntry(id: 'scp-173', title: 'SCP-173', summary: '观测依赖特征的经典档案。'),
    ExploreEntry(id: 'scp-939', title: 'SCP-939', summary: '拟态掠食者的经典档案。'),
    ExploreEntry(id: 'scp-131', title: 'SCP-131', summary: '友善眼状实体的经典档案。'),
  ];

  static final archiveAssets = List<ArchiveAsset>.unmodifiable([
    ArchiveAsset(
      assetId: 'scp-106-mobile-v1',
      contentId: 'scp-106',
      resourcePath: 'assets/models/scp-106.glb',
      source: ArchiveAssetSource.bundled,
      delivery: ArchiveAssetDelivery.bundled,
      version: '1.0.0-mobile-pose',
      byteLength: 8662380,
      sha256:
          'b4141e5b4ca03cce7da388a28d0d18d25a8dbb9d88545e79028ebd965fd0d23b',
      license: _ccBySa30,
      attribution: 'Aruspice（模型/贴图）、Shakles（绑定/动画）、PixelPuffin（概念设计）',
      contentAttribution: '条目来源：SCP Wiki / SCP-106',
      sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp106',
      sourceUrl: _unitySourceUrl('Scp106', 'Scp106'),
      downloadUrl: '',
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-106',
      description: '腐蚀性实体的视觉重建档案。警示：仅呈现外观；不模拟腐蚀性接触、口袋空间或收容失效。',
      objectClass: 'KETER',
      notice: '$_representationNotice 仅呈现外观；不模拟腐蚀性接触、口袋空间或收容失效。',
      modificationNote: _bundledRuntimeNotice,
      estimatedTriangleCount: 16404,
      renderTargetMaxPx: 768,
      initialScale: 1.05,
    ),
    ArchiveAsset(
      assetId: 'scp-049-mobile-v2',
      contentId: 'scp-049',
      resourcePath: 'assets/models/scp-049.glb',
      source: ArchiveAssetSource.bundled,
      delivery: ArchiveAssetDelivery.bundled,
      version: '2.1.0-mobile-pose',
      byteLength: 6947368,
      sha256:
          '7d9fd347d38e67ed2e3b8465b62d27674cacfeeb15c4e31b953fef19e97ef962',
      license: _ccBySa30,
      attribution: 'Aruspice（模型/贴图）、Shakles（绑定/动画）、PixelPuffin（概念设计）',
      contentAttribution: '条目作者：Gabriel Jade；重写：djkaktus、Gabriel Jade',
      sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp049',
      sourceUrl: _unitySourceUrl('Scp049', 'Scp049'),
      downloadUrl: '',
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-049',
      description: '瘟疫医生形象的视觉重建档案。警示：仅呈现外观；不模拟接触感染或异常行为。',
      objectClass: 'EUCLID',
      notice: '$_representationNotice 仅呈现外观；不模拟接触感染或异常行为。',
      modificationNote: _bundledRuntimeNotice,
      estimatedTriangleCount: 12720,
      renderTargetMaxPx: 768,
      initialScale: 1.09,
    ),
    ArchiveAsset(
      assetId: 'scp-173-mobile-v2',
      contentId: 'scp-173',
      resourcePath: 'assets/models/scp-173.glb',
      source: ArchiveAssetSource.bundled,
      delivery: ArchiveAssetDelivery.bundled,
      version: '2.1.0-mobile-pose',
      byteLength: 3969944,
      sha256:
          'f89aefe1f7cf116dc8c12e9c5d554278217afe4744e49e14ab52840ca91f256d',
      license: _ccBySa30,
      attribution: 'Aruspice（模型/贴图）、Shakles（绑定/动画）、PixelPuffin（概念设计）',
      contentAttribution: '条目作者：Moto42',
      sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp173',
      sourceUrl: _unitySourceUrl('Scp173', 'Scp173'),
      downloadUrl: '',
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-173',
      description: '具备观测依赖特征的雕像视觉重建档案。警示：仅呈现静态模型；不模拟眨眼、视线中断或移动事件。',
      objectClass: 'EUCLID',
      notice:
          '$_representationNotice 本资源标记为 NEO/版本 2 重制；仅呈现静态模型，不模拟眨眼、视线中断或移动事件。分发前请复核旧版雕塑形象的许可指南。',
      modificationNote: _bundledRuntimeNotice,
      estimatedTriangleCount: 16104,
      renderTargetMaxPx: 768,
      initialScale: 1.04,
    ),
    ArchiveAsset(
      assetId: 'scp-939-mobile-v2',
      contentId: 'scp-939',
      resourcePath: 'assets/models/scp-939.glb',
      source: ArchiveAssetSource.bundled,
      delivery: ArchiveAssetDelivery.bundled,
      version: '2.1.0-mobile-pose',
      byteLength: 3209604,
      sha256:
          'cd243a640bcba5379609957ebb94beea3c31c2bd8a6e7e8a53e605abe4a33767',
      license: _ccBySa30,
      attribution: 'Apocryphos（模型）、Shadowscale（贴图）、Shakles（绑定/动画）',
      contentAttribution: '条目作者：Adam Smascher、EchoFourDelta',
      sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp939',
      sourceUrl: _unitySourceUrl('Scp939', 'Scp939'),
      downloadUrl: '',
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-939',
      description: '拟态掠食者的视觉重建档案。警示：仅呈现外观；不包含声音拟态、群体行为或感知效果。',
      objectClass: 'KETER',
      notice: '$_representationNotice 仅呈现外观；不包含声音拟态、群体行为或感知效果。',
      modificationNote: _bundledRuntimeNotice,
      estimatedTriangleCount: 10368,
      renderTargetMaxPx: 768,
      initialScale: 1.32,
    ),
    ArchiveAsset(
      assetId: 'scp-131-orange-mobile-v1',
      contentId: 'scp-131',
      resourcePath: '',
      source: ArchiveAssetSource.remote,
      delivery: ArchiveAssetDelivery.onDemand,
      version: '1.0.0-upstream',
      byteLength: 12429448,
      sha256:
          '5e01d45bcb75bff4465f3b6418169919ea35ece79346e0e540d085b704a0a32a',
      license: _ccBySa30,
      attribution: 'Aruspice（模型/贴图）、Shakles（绑定/动画）',
      contentAttribution: '条目作者：Lt Masipag；SCP-131-A 橙色成员',
      sourceLabel:
          'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp131/Scp131Orange',
      sourceUrl: _unitySourceUrl('Scp131', 'Scp131Orange'),
      downloadUrl: _unityRawUrl('Scp131', 'Scp131Orange'),
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-131',
      description: '友善眼状实体 SCP-131-A 的视觉重建档案。警示：仅呈现单体 A；不模拟双体协同行为。',
      objectClass: 'SAFE',
      notice: '$_representationNotice 仅呈现单体 A；不模拟双体协同行为。',
      modificationNote: _remoteRuntimeNotice,
      estimatedTriangleCount: 4104,
      renderTargetMaxPx: 768,
      initialScale: 10.8,
    ),
    ArchiveAsset(
      assetId: 'scp-3199-mobile-v1',
      contentId: 'scp-3199',
      resourcePath: '',
      source: ArchiveAssetSource.remote,
      delivery: ArchiveAssetDelivery.onDemand,
      version: '1.0.0-upstream',
      byteLength: 51054324,
      sha256:
          'c83d9cf29b7282827c94924e1ccd6983c8c94a175b1e0df9a9d7a7e9a76800e1',
      license: _ccBySa30,
      attribution: 'Aruspice（模型/贴图）、Shakles（绑定/动画）',
      contentAttribution: '条目来源：SCP Wiki / SCP-3199',
      sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp3199',
      sourceUrl: _unitySourceUrl('Scp3199', 'Scp3199'),
      downloadUrl: _unityRawUrl('Scp3199', 'Scp3199'),
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-3199',
      description: '鸟类特征异常生物的视觉重建档案。警示：仅呈现外观；不模拟繁殖、攻击或生物危害。',
      objectClass: 'KETER',
      notice: '$_representationNotice 仅呈现外观；不模拟繁殖、攻击或生物危害。',
      modificationNote: _remoteRuntimeNotice,
      estimatedTriangleCount: 16002,
      renderTargetMaxPx: 768,
      initialScale: 1.03,
    ),
    ArchiveAsset(
      assetId: 'scp-650-mobile-v1',
      contentId: 'scp-650',
      resourcePath: '',
      source: ArchiveAssetSource.remote,
      delivery: ArchiveAssetDelivery.onDemand,
      version: '1.0.0-upstream',
      byteLength: 8180984,
      sha256:
          '62bf92f0cd131fc0f71268a264c79eb02b9387c360dc60fe88c89226c5620c44',
      license: _ccBySa30,
      attribution: 'Shadowscale（模型/贴图）',
      contentAttribution: '条目作者：Dr Talson',
      sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp650',
      sourceUrl: _unitySourceUrl('Scp650', 'Scp650'),
      downloadUrl: _unityRawUrl('Scp650', 'Scp650'),
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-650',
      description: '会改变观察位置的雕像视觉重建档案。警示：仅呈现静态外观；不模拟视线外位移或惊吓事件。',
      objectClass: 'EUCLID',
      notice: '$_representationNotice 仅呈现静态外观；不模拟视线外位移或惊吓事件。',
      modificationNote: _remoteRuntimeNotice,
      estimatedTriangleCount: 8640,
      renderTargetMaxPx: 768,
      initialScale: 1.19,
    ),
    ArchiveAsset(
      assetId: 'scp-079-cb-v1',
      contentId: 'scp-079',
      resourcePath: '',
      source: ArchiveAssetSource.remote,
      delivery: ArchiveAssetDelivery.onDemand,
      version: '1.0.0-upstream',
      byteLength: 2771372,
      sha256:
          '6cd62bd301387cfbedaa848c93fbad06cab8c1730702816a94e88b34593a5e83',
      license: _ccBySa30,
      attribution: 'Hakkla（模型/贴图）、Yni（重混）',
      contentAttribution: '条目来源：SCP Wiki / SCP-079',
      sourceLabel: 'Yni-Viar/scp-assets · GFX/SCP-CB/EditedByYni/scp079/079',
      sourceUrl: _assetsSourceUrl(
        'GFX/SCP-CB/EditedByYni/scp079/079/Scp079.glb',
      ),
      downloadUrl: _assetsRawUrl(
        'GFX/SCP-CB/EditedByYni/scp079/079/Scp079.glb',
      ),
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-079',
      description: '早期自适应计算机实体的视觉重建档案。警示：仅呈现硬件外观；不连接网络、不执行其异常智能行为。',
      objectClass: 'EUCLID',
      notice: '$_representationNotice 仅呈现硬件外观；不连接网络、不执行其异常智能行为。',
      modificationNote: _remoteRuntimeNotice,
      estimatedTriangleCount: 13228,
      renderTargetMaxPx: 768,
      initialScale: 4.8,
    ),
    ArchiveAsset(
      assetId: 'scp-178-cb-v1',
      contentId: 'scp-178',
      resourcePath: '',
      source: ArchiveAssetSource.remote,
      delivery: ArchiveAssetDelivery.onDemand,
      version: '1.0.0-upstream',
      byteLength: 2330788,
      sha256:
          '9a2eb124b43470a8208c1235d52a528c9be1ced0c4c2fa509a06e57bbbc62f1e',
      license: _ccBySa30,
      attribution: 'Kenneth crooker（模型）',
      contentAttribution: '条目来源：SCP Wiki / SCP-178',
      sourceLabel: 'Yni-Viar/scp-assets · GFX/SCP-CB/Characters/Scp178-1',
      sourceUrl: _assetsSourceUrl(
        'GFX/SCP-CB/Characters/Scp178-1/Scp178-1.glb',
      ),
      downloadUrl: _assetsRawUrl('GFX/SCP-CB/Characters/Scp178-1/Scp178-1.glb'),
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-178',
      description: 'SCP-178 相关三维实体的视觉重建档案。警示：仅呈现模型；不模拟佩戴眼镜后的异常可见性或认知危害。',
      objectClass: 'SAFE',
      notice: '$_representationNotice 仅呈现模型；不模拟佩戴眼镜后的异常可见性或认知危害。',
      modificationNote: _remoteRuntimeNotice,
      estimatedTriangleCount: 27958,
      renderTargetMaxPx: 768,
      initialScale: 1.12,
    ),
    ArchiveAsset(
      assetId: 'scp-686-icard-v1',
      contentId: 'scp-686',
      resourcePath: '',
      source: ArchiveAssetSource.remote,
      delivery: ArchiveAssetDelivery.onDemand,
      version: '1.0.0-upstream',
      byteLength: 129020,
      sha256:
          '2b90bc9eb186054dc8ed6200a1195b9444c526460ba4699baead9def1cb8f207',
      license: _ccBySa30,
      attribution: 'pop_pop_icard（模型）',
      contentAttribution: '条目来源：SCP Wiki / SCP-686',
      sourceLabel: 'Yni-Viar/scp-assets · GFX/By_Pop_Pop_Icard/Items/Scp686',
      sourceUrl: _assetsSourceUrl(
        'GFX/By_Pop_Pop_Icard/Items/Scp686/Scp686.glb',
      ),
      downloadUrl: _assetsRawUrl(
        'GFX/By_Pop_Pop_Icard/Items/Scp686/Scp686.glb',
      ),
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-686',
      description: '感染性乳状液体容器的视觉重建档案。警示：仅呈现容器外观；不要接触或摄入内容物。',
      objectClass: 'SAFE',
      notice: '$_representationNotice 仅呈现容器外观；不要接触或摄入实体内容物，应用不模拟其感染效应。',
      modificationNote: _remoteRuntimeNotice,
      estimatedTriangleCount: 2242,
      renderTargetMaxPx: 768,
      initialScale: 8.8,
    ),
  ]);

  static bool hasArchiveAsset(String itemId) => archiveAssets.any(
    (asset) => asset.contentId.toLowerCase() == itemId.trim().toLowerCase(),
  );

  static ArchiveAsset? archiveAssetFor(String itemId) {
    for (final asset in archiveAssets) {
      if (asset.contentId.toLowerCase() == itemId.trim().toLowerCase()) {
        return asset;
      }
    }
    return null;
  }

  static String _unitySourceUrl(String folder, String fileName) =>
      '$_sourceRepository/blob/$_sourceCommit/Rigged-Ready/$folder/$fileName.glb';

  static String _unityRawUrl(String folder, String fileName) =>
      'https://raw.githubusercontent.com/Yni-Viar/scp-unity-assets/$_sourceCommit/Rigged-Ready/$folder/$fileName.glb';

  static String _assetsSourceUrl(String path) =>
      '$_assetsRepository/blob/$_assetsCommit/$path';

  static String _assetsRawUrl(String path) =>
      'https://raw.githubusercontent.com/Yni-Viar/scp-assets/$_assetsCommit/$path';
}
