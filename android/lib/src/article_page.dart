part of 'anomicon_app.dart';

class ArticleScreen extends StatefulWidget {
  const ArticleScreen({
    required this.content,
    required this.settings,
    required this.repository,
    required this.localStore,
    required this.favorite,
    required this.onBack,
    required this.onToggleFavorite,
    required this.onLibraryChanged,
    required this.onOpenArchive,
    super.key,
  });

  final ContentRef content;
  final AppSettings settings;
  final AnomiconRepository repository;
  final LocalStore localStore;
  final bool favorite;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;
  final ValueChanged<LibrarySnapshot> onLibraryChanged;
  final ValueChanged<ArchiveAsset> onOpenArchive;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  late Future<ArticleDocument> _future;
  late final ScrollController _controller;
  int _lastCreditAt = 0;
  ArticleDocument? _document;
  File? _previewFile;

  @override
  void initState() {
    super.initState();
    final existing = widget.localStore
        .loadLibrary()
        .history
        .where((entry) => entry.content.key == widget.content.key)
        .firstOrNull;
    _controller = ScrollController(
      initialScrollOffset: (existing?.scrollOffset ?? 0) * 220.0,
    );
    _controller.addListener(_recordScrollCheckpoint);
    _future = _load();
  }

  Future<ArticleDocument> _load() async {
    final document = await widget.repository.loadArticle(widget.content);
    _document = document;
    widget.onLibraryChanged(
      await widget.localStore.recordRead(
        widget.content,
        scrollOffset: _blockIndex,
        blockCount: document.blocks.length,
      ),
    );
    return document;
  }

  int get _blockIndex {
    final count = _document?.blocks.length ?? 0;
    if (count == 0 || !_controller.hasClients) return 0;
    return (_controller.offset / 220).floor().clamp(0, math.max(0, count - 1));
  }

  Future<void> _recordScrollCheckpoint() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastCreditAt < 1200 || _document == null) return;
    _lastCreditAt = now;
    widget.onLibraryChanged(
      await widget.localStore.recordRead(
        widget.content,
        scrollOffset: _blockIndex,
        blockCount: _document!.blocks.length,
        creditActiveTime: true,
      ),
    );
  }

  @override
  void dispose() {
    _recordScrollCheckpoint();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final archiveAsset = SeedData.archiveAssetFor(widget.content.id);
    return DetailCanvas(
      onBack: widget.onBack,
      title: widget.content.title,
      subtitle: widget.content.id,
      actions: <Widget>[
        if (archiveAsset != null)
          GlassIconButton(
            icon: Icons.view_in_ar_rounded,
            label: '三维档案',
            onPressed: () => widget.onOpenArchive(archiveAsset),
          ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: widget.favorite
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          label: widget.favorite ? '取消收藏' : '收藏',
          onPressed: widget.onToggleFavorite,
        ),
      ],
      child: FutureBuilder<ArticleDocument>(
        future: _future,
        builder: (context, snapshot) {
          final document = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting &&
              document == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || document == null) {
            return ArticleError(
              message: snapshot.error?.toString() ?? '文章暂时不可用',
              onRetry: () => setState(() => _future = _load()),
              onOpenOriginal: () =>
                  _openExternal(articleUrlOf(widget.content.id)),
            );
          }
          final progress = document.blocks.length <= 1
              ? 1.0
              : (_blockIndex / math.max(1, document.blocks.length - 1)).clamp(
                  0.0,
                  1.0,
                );
          return Stack(
            children: <Widget>[
              ListView.separated(
                controller: _controller,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 44),
                itemCount: document.blocks.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '原生阅读 · ${document.blocks.length} 个内容块',
                          style: const TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  }
                  if (index == document.blocks.length + 1) {
                    return const Text(
                      '内容来自 SCP Wiki 缓存；图片按需缓存到本机。',
                      style: TextStyle(color: _muted, fontSize: 12),
                    );
                  }
                  return ArticleBlockView(
                    block: document.blocks[index - 1],
                    settings: widget.settings,
                    repository: widget.repository,
                    onImageLoaded: (file) =>
                        setState(() => _previewFile = file),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_previewFile != null)
                ImagePreviewDialog(
                  file: _previewFile!,
                  onDismiss: () => setState(() => _previewFile = null),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ArticleBlockView extends StatelessWidget {
  const ArticleBlockView({
    required this.block,
    required this.settings,
    required this.repository,
    required this.onImageLoaded,
    super.key,
  });

  final ArticleBlock block;
  final AppSettings settings;
  final AnomiconRepository repository;
  final ValueChanged<File> onImageLoaded;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = TextStyle(
      fontSize: settings.fontSize,
      height: settings.lineHeightMultiple,
      color: const Color(0xFFE7E8EA),
      fontWeight: FontWeight.w500,
    );
    return switch (block) {
      ArticleHeading(:final text, :final level) => Padding(
        padding: EdgeInsets.only(top: level <= 2 ? 10 : 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: level == 1
                ? 30
                : level == 2
                ? 25
                : 21,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      ArticleParagraph(:final text) => Text(text, style: bodyStyle),
      ArticleQuote(:final text) => GlassCard(
        color: _surfaceLow,
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: bodyStyle.copyWith(color: const Color(0xFFC9CED2)),
        ),
      ),
      ArticleListBlock(:final items, :final ordered) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.indexed.map((entry) {
          final marker = ordered ? '${entry.$1 + 1}.' : '•';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('$marker ${entry.$2}', style: bodyStyle),
          );
        }).toList(),
      ),
      ArticleImage() => CachedArticleImage(
        image: block as ArticleImage,
        repository: repository,
        onImageLoaded: onImageLoaded,
      ),
      ArticleDivider() => const Divider(color: Color(0xFF3F4448)),
    };
  }
}

class CachedArticleImage extends StatefulWidget {
  const CachedArticleImage({
    required this.image,
    required this.repository,
    required this.onImageLoaded,
    super.key,
  });

  final ArticleImage image;
  final AnomiconRepository repository;
  final ValueChanged<File> onImageLoaded;

  @override
  State<CachedArticleImage> createState() => _CachedArticleImageState();
}

class _CachedArticleImageState extends State<CachedArticleImage> {
  late Future<File> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadImageFile(widget.image.url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final file = snapshot.data!;
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: GestureDetector(
              onTap: () => widget.onImageLoaded(file),
              child: Image.file(file, fit: BoxFit.cover),
            ),
          );
        }
        if (snapshot.hasError) {
          return Text(
            widget.image.alt.isEmpty ? '图片暂时不可用' : widget.image.alt,
            style: const TextStyle(color: _muted),
          );
        }
        return Container(
          height: 160,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const CircularProgressIndicator(),
        );
      },
    );
  }
}

class ImagePreviewDialog extends StatelessWidget {
  const ImagePreviewDialog({
    required this.file,
    required this.onDismiss,
    super.key,
  });

  final File file;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.82),
        child: Center(
          child: GestureDetector(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ArticleError extends StatelessWidget {
  const ArticleError({
    required this.message,
    required this.onRetry,
    required this.onOpenOriginal,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.cloud_off_rounded, color: _muted, size: 48),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: _muted),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  FilledButton(onPressed: onRetry, child: const Text('重试')),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onOpenOriginal,
                    child: const Text('原文'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
