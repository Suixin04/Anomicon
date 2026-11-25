part of 'anomicon_app.dart';

const _archiveBlue = Color(0xFF242C42);

class ArchiveGalleryScreen extends StatefulWidget {
  const ArchiveGalleryScreen({
    required this.repository,
    required this.onBack,
    required this.onOpenAsset,
    required this.onOpenArticle,
    required this.onHaptic,
    super.key,
  });

  final AnomiconRepository repository;
  final VoidCallback onBack;
  final ValueChanged<ArchiveAsset> onOpenAsset;
  final ValueChanged<ContentRef> onOpenArticle;
  final VoidCallback onHaptic;

  @override
  State<ArchiveGalleryScreen> createState() => _ArchiveGalleryScreenState();
}

class _ArchiveGalleryScreenState extends State<ArchiveGalleryScreen> {
  var _filter = 'all';
  var _installed = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _refreshInstalled();
  }

  Future<void> _refreshInstalled() async {
    final next = <String, bool>{};
    for (final asset in SeedData.archiveAssets) {
      next[asset.assetId] =
          asset.isReadyByDefault ||
          await widget.repository.installedArchiveAsset(asset) != null;
    }
    if (!mounted) return;
    setState(() => _installed = next);
  }

  @override
  Widget build(BuildContext context) {
    final installedCount = SeedData.archiveAssets
        .where((asset) => _installed[asset.assetId] ?? asset.isReadyByDefault)
        .length;
    final visible = SeedData.archiveAssets.where((asset) {
      final isInstalled = _installed[asset.assetId] ?? asset.isReadyByDefault;
      return _filter == 'all' ||
          (_filter == 'installed' && isInstalled) ||
          (_filter == 'pending' && !isInstalled);
    }).toList();
    return DetailCanvas(
      onBack: widget.onBack,
      title: '三维档案馆',
      subtitle: '${SeedData.archiveAssets.length} 个档案',
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: HorizontalPills(
              labels: <String, String>{
                'all': '全部 ${SeedData.archiveAssets.length}',
                'installed': '已下载 $installedCount',
                'pending':
                    '待下载 ${SeedData.archiveAssets.length - installedCount}',
              },
              selected: _filter,
              onSelected: (value) {
                widget.onHaptic();
                setState(() => _filter = value);
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            sliver: SliverList.separated(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final asset = visible[index];
                return ArchiveGalleryCard(
                  asset: asset,
                  installed:
                      _installed[asset.assetId] ?? asset.isReadyByDefault,
                  onOpenAsset: () => widget.onOpenAsset(asset),
                  onOpenArticle: () => widget.onOpenArticle(asset.contentRef),
                  onDelete: asset.delivery == ArchiveAssetDelivery.onDemand
                      ? () async {
                          await widget.repository.deleteArchiveAsset(asset);
                          await _refreshInstalled();
                        }
                      : null,
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class ArchiveDetailScreen extends StatefulWidget {
  const ArchiveDetailScreen({
    required this.asset,
    required this.repository,
    required this.onBack,
    required this.onOpenArticle,
    super.key,
  });

  final ArchiveAsset asset;
  final AnomiconRepository repository;
  final VoidCallback onBack;
  final VoidCallback onOpenArticle;

  @override
  State<ArchiveDetailScreen> createState() => _ArchiveDetailScreenState();
}

class _ArchiveDetailScreenState extends State<ArchiveDetailScreen> {
  File? _installedFile;
  ArchiveDownloadProgress? _progress;
  String? _error;
  var _downloading = false;
  var _autoRotate = true;

  @override
  void initState() {
    super.initState();
    _loadInstalled();
  }

  Future<void> _loadInstalled() async {
    final file = await widget.repository.installedArchiveAsset(widget.asset);
    if (!mounted) return;
    setState(() => _installedFile = file);
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _error = null;
      _progress = null;
    });
    try {
      final file = await widget.repository.downloadArchiveAsset(
        widget.asset,
        onProgress: (progress) => setState(() => _progress = progress),
      );
      if (!mounted) return;
      setState(() => _installedFile = file);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final installed = asset.isReadyByDefault || _installedFile != null;
    final modelSrc = asset.isReadyByDefault
        ? asset.resourcePath
        : _installedFile?.uri.toString() ?? asset.downloadUrl;
    return DetailCanvas(
      onBack: widget.onBack,
      title: '三维档案',
      subtitle: asset.title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: 430,
              child: installed
                  ? ModelViewer(
                      backgroundColor: _archiveBlue,
                      src: modelSrc,
                      alt: '${asset.title} GLB',
                      autoRotate: _autoRotate,
                      cameraControls: true,
                      disableZoom: false,
                    )
                  : RemoteArchivePlaceholder(
                      asset: asset,
                      progress: _progress,
                      downloading: _downloading,
                      error: _error,
                      onDownload: _download,
                    ),
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                FilledButton(
                  onPressed: installed
                      ? () => setState(() => _autoRotate = !_autoRotate)
                      : null,
                  child: Text(_autoRotate ? '停止旋转' : '自动旋转'),
                ),
                FilledButton(
                  onPressed: installed
                      ? () => setState(() => _autoRotate = true)
                      : null,
                  child: const Text('复位'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            '档案说明',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '对象等级 · ${asset.objectClass}',
                            style: const TextStyle(color: _muted, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _openExternal(asset.sourceUrl),
                      child: const Text('来源'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  asset.description,
                  style: const TextStyle(
                    color: Color(0xFFB9BEC3),
                    fontSize: 17,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 22),
                const Divider(color: Color(0xFF3F4448)),
                MetadataRow(label: '格式', value: 'GLB'),
                MetadataRow(label: '大小', value: formatBytes(asset.byteLength)),
                MetadataRow(label: '档案版本', value: asset.version),
                MetadataRow(
                  label: '交付方式',
                  value: asset.delivery == ArchiveAssetDelivery.bundled
                      ? '随应用内置'
                      : '按需下载',
                ),
                MetadataRow(label: '许可证', value: asset.license),
                MetadataRow(label: '归因', value: asset.attribution),
                const SizedBox(height: 12),
                Text(
                  asset.modificationNote,
                  style: const TextStyle(color: _muted, height: 1.45),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onOpenArticle,
                        child: const Text('打开条目'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openExternal(asset.contentSourceUrl),
                        child: const Text('英文来源'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ArchiveGalleryCard extends StatelessWidget {
  const ArchiveGalleryCard({
    required this.asset,
    required this.installed,
    required this.onOpenAsset,
    required this.onOpenArticle,
    this.onDelete,
    super.key,
  });

  final ArchiveAsset asset;
  final bool installed;
  final VoidCallback onOpenAsset;
  final VoidCallback onOpenArticle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpenAsset,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      asset.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  StatusPill(
                    text: asset.delivery == ArchiveAssetDelivery.bundled
                        ? '随应用内置'
                        : installed
                        ? '已下载'
                        : '待下载',
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _muted,
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                asset.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB6BAC0),
                  fontSize: 18,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Text(
                    asset.objectClass,
                    style: const TextStyle(color: _muted, fontSize: 18),
                  ),
                  const Spacer(),
                  Text(
                    'GLB  ${formatBytes(asset.byteLength)}',
                    style: const TextStyle(color: _muted, fontSize: 18),
                  ),
                ],
              ),
              if (onDelete != null && installed) ...<Widget>[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: onDelete,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFE1E1),
                      foregroundColor: const Color(0xFF9B2D2D),
                    ),
                    child: const Text('删除'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF315B9F),
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class RemoteArchivePlaceholder extends StatelessWidget {
  const RemoteArchivePlaceholder({
    required this.asset,
    required this.progress,
    required this.downloading,
    required this.error,
    required this.onDownload,
    super.key,
  });

  final ArchiveAsset asset;
  final ArchiveDownloadProgress? progress;
  final bool downloading;
  final String? error;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final fraction = progress?.fraction;
    return Container(
      color: _archiveBlue,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.cloud_download_rounded,
            size: 64,
            color: Colors.white70,
          ),
          const SizedBox(height: 16),
          Text(
            asset.title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            downloading
                ? progress == null
                      ? '正在准备下载...'
                      : '正在下载 ${formatDownloadProgress(progress!)}'
                : '按需下载后保存到应用私有缓存，并校验大小与 SHA-256。',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFC3C9D1),
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          if (downloading)
            LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              borderRadius: BorderRadius.circular(99),
            )
          else
            FilledButton.icon(
              onPressed: asset.downloadUrl.isEmpty ? null : onDownload,
              icon: const Icon(Icons.cloud_download_rounded),
              label: const Text('下载并查看'),
            ),
          if (error != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFA5A5)),
            ),
          ],
        ],
      ),
    );
  }
}

class MetadataRow extends StatelessWidget {
  const MetadataRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 17),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatDownloadProgress(ArchiveDownloadProgress progress) {
  final fraction = progress.fraction;
  if (fraction == null) {
    return formatBytes(progress.downloadedBytes);
  }
  return '${(fraction * 100).round()}% · ${formatBytes(progress.downloadedBytes)} / ${formatBytes(progress.totalBytes)}';
}
