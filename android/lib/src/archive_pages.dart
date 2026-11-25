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
    widget.repository.archiveAssetStore.installedRevision.addListener(
      _refreshInstalled,
    );
    _refreshInstalled();
  }

  @override
  void dispose() {
    widget.repository.archiveAssetStore.installedRevision.removeListener(
      _refreshInstalled,
    );
    super.dispose();
  }

  Future<void> _refreshInstalled() async {
    final revision =
        widget.repository.archiveAssetStore.installedRevision.value;
    final next = <String, bool>{};
    for (final asset in SeedData.archiveAssets) {
      next[asset.assetId] =
          asset.isReadyByDefault ||
          await widget.repository.installedArchiveAsset(asset) != null;
    }
    if (!mounted ||
        revision !=
            widget.repository.archiveAssetStore.installedRevision.value) {
      return;
    }
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
  var _checking = true;
  int _loadSequence = 0;

  ArchiveAssetStore get _store => widget.repository.archiveAssetStore;

  @override
  void initState() {
    super.initState();
    _store.installedRevision.addListener(_loadInstalled);
    _loadInstalled();
    if (!widget.asset.isReadyByDefault) _store.restoreProgress(widget.asset);
  }

  @override
  void didUpdateWidget(covariant ArchiveDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _checking = true;
      _installedFile = null;
      _loadInstalled();
      if (!widget.asset.isReadyByDefault) _store.restoreProgress(widget.asset);
    }
  }

  @override
  void dispose() {
    _store.installedRevision.removeListener(_loadInstalled);
    super.dispose();
  }

  Future<void> _loadInstalled() async {
    final sequence = ++_loadSequence;
    final asset = widget.asset;
    final file = asset.isReadyByDefault
        ? null
        : await _store.installedFile(asset);
    if (!mounted || sequence != _loadSequence) return;
    setState(() {
      _installedFile = file;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final modelSrc = asset.isReadyByDefault
        ? asset.resourcePath
        : _installedFile?.uri.toString();
    final theme = Theme.of(context);
    return DetailCanvas(
      onBack: widget.onBack,
      title: '三维档案',
      subtitle: asset.title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: [
          if (modelSrc != null)
            SizedBox(
              height: 400,
              child: _ArchiveStage(
                key: ValueKey(modelSrc),
                asset: asset,
                src: modelSrc,
              ),
            )
          else if (_checking)
            const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ValueListenableBuilder<ArchiveDownloadState>(
              valueListenable: _store.stateOf(asset),
              builder: (context, state, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_download_outlined, size: 42),
                      const SizedBox(height: 12),
                      Text('按需下载 · ${formatBytes(asset.byteLength)}'),
                      if (state.progress case final progress?) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: progress.fraction),
                        Text(formatDownloadProgress(progress)),
                      ] else if (state.downloading) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                      if (state.error case final error?) ...[
                        const SizedBox(height: 12),
                        Text(
                          error,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: state.downloading
                            ? () => _store.pause(asset)
                            : () => _store.download(asset),
                        icon: Icon(
                          state.downloading ? Icons.pause : Icons.download,
                        ),
                        label: Text(
                          state.downloading
                              ? '暂停下载'
                              : state.progress != null
                              ? '继续下载'
                              : state.error != null
                              ? '重试下载'
                              : '获取此模型',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.title, style: theme.textTheme.headlineSmall),
                  Text('对象等级 · ${asset.objectClass}'),
                  const SizedBox(height: 12),
                  Text(asset.description),
                  const SizedBox(height: 12),
                  Text(asset.notice),
                  const Divider(),
                  MetadataRow(
                    label: '格式与大小',
                    value: 'GLB · ${formatBytes(asset.byteLength)}',
                  ),
                  MetadataRow(label: '档案版本', value: asset.version),
                  MetadataRow(
                    label: '交付方式',
                    value: asset.isReadyByDefault ? '随应用内置' : '按需下载',
                  ),
                  MetadataRow(label: '许可证', value: asset.license),
                  MetadataRow(label: '模型归因', value: asset.attribution),
                  MetadataRow(label: '条目归因', value: asset.contentAttribution),
                  MetadataRow(label: '模型来源', value: asset.sourceLabel),
                  Text(asset.modificationNote),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: widget.onOpenArticle,
                        child: const Text('打开条目'),
                      ),
                      OutlinedButton(
                        onPressed: () => _openExternal(asset.contentSourceUrl),
                        child: const Text('英文条目'),
                      ),
                      OutlinedButton(
                        onPressed: () => _openExternal(asset.sourceUrl),
                        child: const Text('模型源文件'),
                      ),
                      OutlinedButton(
                        onPressed: () => _openExternal(
                          'https://creativecommons.org/licenses/by-sa/3.0/',
                        ),
                        child: const Text('许可证全文'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveStage extends StatefulWidget {
  const _ArchiveStage({
    required this.asset,
    required this.src,
    this.fullScreen = false,
    super.key,
  });

  final ArchiveAsset asset;
  final String src;
  final bool fullScreen;

  @override
  State<_ArchiveStage> createState() => _ArchiveStageState();
}

class _ArchiveStageState extends State<_ArchiveStage> {
  Future<void> Function(String)? _runJavaScript;
  var _autoRotate = false;
  var _generation = 0;

  Future<void> _toggleRotation() async {
    final rotate = !_autoRotate;
    await _runJavaScript?.call(
      "document.querySelector('model-viewer')?.toggleAttribute('auto-rotate', $rotate);",
    );
    if (mounted) setState(() => _autoRotate = rotate);
  }

  void _openFullscreen() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(widget.asset.title)),
          body: SafeArea(
            child: _ArchiveStage(
              asset: widget.asset,
              src: widget.src,
              fullScreen: true,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ModelViewer(
            key: ValueKey(_generation),
            backgroundColor: _archiveBlue,
            src: widget.src,
            alt: '${widget.asset.title} GLB',
            cameraControls: true,
            touchAction: TouchAction.panY,
            onWebViewCreated: (controller) =>
                _runJavaScript = controller.runJavaScript,
            relatedJs: """
              const model = document.querySelector('model-viewer');
              model.addEventListener('error', () => {
                const error = document.createElement('div');
                error.textContent = '无法显示模型，请复位重试。';
                error.style.cssText = 'position:absolute;top:8px;left:8px;color:white;background:#242c42;padding:8px';
                document.body.append(error);
              });
            """,
          ),
        ),
      ),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          IconButton(
            tooltip: _autoRotate ? '停止旋转' : '自动旋转',
            onPressed: _toggleRotation,
            icon: Icon(_autoRotate ? Icons.pause : Icons.threesixty),
          ),
          IconButton(
            tooltip: '复位',
            onPressed: () => setState(() {
              _autoRotate = false;
              _runJavaScript = null;
              _generation++;
            }),
            icon: const Icon(Icons.restart_alt),
          ),
          if (!widget.fullScreen)
            IconButton(
              tooltip: '全屏查看',
              onPressed: _openFullscreen,
              icon: const Icon(Icons.fullscreen),
            ),
        ],
      ),
    ],
  );
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
    final colors = Theme.of(context).colorScheme;
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
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    asset.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  StatusPill(
                    text: asset.isReadyByDefault
                        ? '随应用内置'
                        : installed
                        ? '已下载'
                        : '待下载',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                asset.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 18,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  Text(
                    asset.objectClass,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  Text(
                    'GLB · ${formatBytes(asset.byteLength)}',
                    style: TextStyle(color: colors.onSurfaceVariant),
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
                      backgroundColor: colors.errorContainer,
                      foregroundColor: colors.onErrorContainer,
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.onSecondaryContainer,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 16,
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
  return '${(fraction * 100).round()}% · ${formatBytes(progress.downloadedBytes)} / ${formatBytes(progress.totalBytes)}';
}
