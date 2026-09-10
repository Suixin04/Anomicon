import 'models.dart';

class SeedData {
  static const _sourceRepository = 'https://github.com/Yni-Viar/scp-unity-assets';
  static const _sourceCommit = '7fda38944f51db7ee3aeb4d9e5ca821263153da5';
  static const _assetsRepository = 'https://github.com/Yni-Viar/scp-assets';
  static const _assetsCommit = '1265487d1978b60398ab71f366bc5a1ba4ce1d0d';
  static const _ccBySa30 = 'CC BY-SA 3.0';
  static const _representationNotice = '社区创作的视觉重建，不代表 SCP 官方形象或实体复原。';
  static const _bundledRuntimeNotice = '上游自包含 GLB 已随 Flutter Android 包体内置；查看器负责触控旋转、缩放和复位。';
  static const _remoteRuntimeNotice = '按需下载上游自包含 GLB；下载后校验大小与 SHA-256，并可在本机删除。';

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

  static final archiveAssets = <ArchiveAsset>[
    _bundled(
      assetId: 'scp-106-upstream-bundled-v1',
      contentId: 'scp-106',
      resourcePath: 'assets/models/scp-106.glb',
      rawUrl: _unityRawUrl('Scp106', 'Scp106'),
      version: '1.0.0-upstream-bundled',
      byteLength: 34872408,
      sha256: '04dbfc8ced0e10ec3be39fb1f9a8bfc87282543ba16c80b9afa5c27edb4bec17',
      attribution: 'Aruspice（模型/贴图）、Shakles（绑定/动画）、PixelPuffin（概念设计）',
      contentAttribution: '条目来源：SCP Wiki / SCP-106',
      sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp106',
      sourceUrl: _unitySourceUrl('Scp106', 'Scp106'),
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-106',
      description: '腐蚀性实体的视觉重建档案。警示：仅呈现外观；不模拟腐蚀性接触、口袋空间或收容失效。',
      objectClass: 'KETER',
      estimatedTriangleCount: 16404,
      initialScale: 1.05,
    ),
    _bundled(
      assetId: 'scp-049-upstream-bundled-v1',
      contentId: 'scp-049',
      resourcePath: 'assets/models/scp-049.glb',
      rawUrl: _unityRawUrl('Scp049', 'Scp049'),
      version: '1.0.0-upstream-bundled',
      byteLength: 29540408,
      sha256: 'bc4cfba3e787b66a60801a93c9a539897830073ce9f612fe492b6e1e509bdf99',
      attribution: 'Aruspice（模型/贴图）、Shakles（绑定/动画）、PixelPuffin（概念设计）',
      contentAttribution: '条目作者：Gabriel Jade；重写：djkaktus、Gabriel Jade',
      sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp049',
      sourceUrl: _unitySourceUrl('Scp049', 'Scp049'),
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-049',
      description: '瘟疫医生形象的视觉重建档案。警示：仅呈现外观；不模拟接触感染或异常行为。',
      objectClass: 'EUCLID',
      estimatedTriangleCount: 12720,
      initialScale: 1.09,
    ),
    _bundled(
      assetId: 'scp-173-upstream-bundled-v1',
      contentId: 'scp-173',
      resourcePath: 'assets/models/scp-173.glb',
      rawUrl: _unityRawUrl('Scp173', 'Scp173'),
      version: '1.0.0-upstream-bundled',
      byteLength: 17013568,
      sha256: '01f6c483d9120ef549eae88e76ca7e66690d6aeef758132aed95665e4f33bc99',
      attribution: 'Aruspice（模型/贴图）、Shakles（绑定/动画）、PixelPuffin（概念设计）',
      contentAttribution: '条目作者：Moto42',
      sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp173',
      sourceUrl: _unitySourceUrl('Scp173', 'Scp173'),
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-173',
      description: '具备观测依赖特征的雕像视觉重建档案。警示：仅呈现静态模型；不模拟眨眼、视线中断或移动事件。',
      objectClass: 'EUCLID',
      estimatedTriangleCount: 16104,
      initialScale: 1.04,
    ),
    _bundled(
      assetId: 'scp-939-upstream-bundled-v1',
      contentId: 'scp-939',
      resourcePath: 'assets/models/scp-939.glb',
      rawUrl: _unityRawUrl('Scp939', 'Scp939'),
      version: '1.0.0-upstream-bundled',
      byteLength: 11557696,
      sha256: 'a4aed436f38f941690f67b4ac1bfe2f505c4b375d533bd382f89754c3d27d1f0',
      attribution: 'Apocryphos（模型）、Shadowscale（贴图）、Shakles（绑定/动画）',
      contentAttribution: '条目作者：Adam Smascher、EchoFourDelta',
      sourceLabel: 'Yni-Viar/scp-unity-assets · Rigged-Ready/Scp939',
      sourceUrl: _unitySourceUrl('Scp939', 'Scp939'),
      contentSourceUrl: 'https://scp-wiki.wikidot.com/scp-939',
      description: '拟态掠食者的视觉重建档案。警示：仅呈现外观；不包含声音拟态、群体行为或感知效果。',
      objectClass: 'KETER',
      estimatedTriangleCount: 10368,
      initialScale: 1.32,
    ),
    _remote('scp-131-orange-upstream-v1', 'scp-131', 12429448, '5e01d45bcb75bff4465f3b6418169919ea35ece79346e0e540d085b704a0a32a', 'Scp131', 'Scp131Orange', '友善眼状实体 SCP-131-A 的视觉重建档案。', 'SAFE', 4104, 10.8),
    _remote('scp-3199-upstream-v1', 'scp-3199', 51054324, 'c83d9cf29b7282827c94924e1ccd6983c8c94a175b1e0df9a9d7a7e9a76800e1', 'Scp3199', 'Scp3199', '鸟类特征异常生物的视觉重建档案。', 'KETER', 16002, 1.03),
    _remote('scp-650-upstream-v1', 'scp-650', 8180984, '62bf92f0cd131fc0f71268a264c79eb02b9387c360dc60fe88c89226c5620c44', 'Scp650', 'Scp650', '会改变观察位置的雕像视觉重建档案。', 'EUCLID', 8640, 1.19),
    _remote(
      'scp-079-cb-v1',
      'scp-079',
      2771372,
      '6cd62bd301387cfbedaa848c93fbad06cab8c1730702816a94e88b34593a5e83',
      'GFX/SCP-CB/EditedByYni/scp079/079',
      'Scp079',
      '早期自适应计算机实体的视觉重建档案。',
      'EUCLID',
      13228,
      4.8,
      assetsRepository: true,
    ),
    _remote(
      'scp-178-cb-v1',
      'scp-178',
      2330788,
      '9a2eb124b43470a8208c1235d52a528c9be1ced0c4c2fa509a06e57bbbc62f1e',
      'GFX/SCP-CB/Characters/Scp178-1',
      'Scp178-1',
      'SCP-178 相关三维实体的视觉重建档案。',
      'SAFE',
      27958,
      1.12,
      assetsRepository: true,
    ),
    _remote(
      'scp-686-icard-v1',
      'scp-686',
      129020,
      '2b90bc9eb186054dc8ed6200a1195b9444c526460ba4699baead9def1cb8f207',
      'GFX/By_Pop_Pop_Icard/Items/Scp686',
      'Scp686',
      '感染性乳状液体容器的视觉重建档案。',
      'SAFE',
      2242,
      8.8,
      assetsRepository: true,
    ),
  ];

  static bool hasArchiveAsset(String itemId) =>
      archiveAssets.any((asset) => asset.contentId.toLowerCase() == itemId.trim().toLowerCase());

  static ArchiveAsset? archiveAssetFor(String itemId) {
    for (final asset in archiveAssets) {
      if (asset.contentId.toLowerCase() == itemId.trim().toLowerCase()) {
        return asset;
      }
    }
    return null;
  }

  static ArchiveAsset _bundled({
    required String assetId,
    required String contentId,
    required String resourcePath,
    required String rawUrl,
    required String version,
    required int byteLength,
    required String sha256,
    required String attribution,
    required String contentAttribution,
    required String sourceLabel,
    required String sourceUrl,
    required String contentSourceUrl,
    required String description,
    required String objectClass,
    required int estimatedTriangleCount,
    required double initialScale,
  }) => ArchiveAsset(
    assetId: assetId,
    contentId: contentId,
    resourcePath: resourcePath,
    source: ArchiveAssetSource.bundled,
    delivery: ArchiveAssetDelivery.bundled,
    version: version,
    byteLength: byteLength,
    sha256: sha256,
    license: _ccBySa30,
    attribution: attribution,
    contentAttribution: contentAttribution,
    sourceLabel: sourceLabel,
    sourceUrl: sourceUrl,
    downloadUrl: rawUrl,
    contentSourceUrl: contentSourceUrl,
    description: description,
    objectClass: objectClass,
    notice: '$_representationNotice $description',
    modificationNote: _bundledRuntimeNotice,
    estimatedTriangleCount: estimatedTriangleCount,
    renderTargetMaxPx: 768,
    initialScale: initialScale,
  );

  static ArchiveAsset _remote(
    String assetId,
    String contentId,
    int byteLength,
    String sha256,
    String folder,
    String fileName,
    String description,
    String objectClass,
    int estimatedTriangleCount,
    double initialScale, {
    bool assetsRepository = false,
  }) {
    final path = '$folder/$fileName.glb';
    final sourceUrl = assetsRepository ? _assetsSourceUrl(path) : _unitySourceUrl(folder, fileName);
    final rawUrl = assetsRepository ? _assetsRawUrl(path) : _unityRawUrl(folder, fileName);
    final sourceLabel = assetsRepository
        ? 'Yni-Viar/scp-assets · $path'
        : 'Yni-Viar/scp-unity-assets · Rigged-Ready/$folder/$fileName';
    return ArchiveAsset(
      assetId: assetId,
      contentId: contentId,
      resourcePath: '',
      source: ArchiveAssetSource.remote,
      delivery: ArchiveAssetDelivery.onDemand,
      version: '1.0.0-upstream',
      byteLength: byteLength,
      sha256: sha256,
      license: _ccBySa30,
      attribution: '社区三维资源作者，详见来源仓库',
      contentAttribution: '条目来源：SCP Wiki / ${contentId.toUpperCase()}',
      sourceLabel: sourceLabel,
      sourceUrl: sourceUrl,
      downloadUrl: rawUrl,
      contentSourceUrl: 'https://scp-wiki.wikidot.com/$contentId',
      description: description,
      objectClass: objectClass,
      notice: '$_representationNotice $description',
      modificationNote: _remoteRuntimeNotice,
      estimatedTriangleCount: estimatedTriangleCount,
      renderTargetMaxPx: 768,
      initialScale: initialScale,
    );
  }

  static String _unitySourceUrl(String folder, String fileName) =>
      '$_sourceRepository/blob/$_sourceCommit/Rigged-Ready/$folder/$fileName.glb';

  static String _unityRawUrl(String folder, String fileName) =>
      'https://raw.githubusercontent.com/Yni-Viar/scp-unity-assets/$_sourceCommit/Rigged-Ready/$folder/$fileName.glb';

  static String _assetsSourceUrl(String path) => '$_assetsRepository/blob/$_assetsCommit/$path';

  static String _assetsRawUrl(String path) =>
      'https://raw.githubusercontent.com/Yni-Viar/scp-assets/$_assetsCommit/$path';
}
