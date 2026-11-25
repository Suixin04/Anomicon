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
    this.offline = false,
    this.onOpenContent,
    this.onOpenSettings,
    this.onReport,
    super.key,
  });

  final ContentRef content;
  final AppSettings settings;
  final AnomiconRepository repository;
  final LocalStore localStore;
  final bool favorite;
  final bool offline;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;
  final ValueChanged<LibrarySnapshot> onLibraryChanged;
  final ValueChanged<ArchiveAsset> onOpenArchive;
  final ValueChanged<ContentRef>? onOpenContent;
  final VoidCallback? onOpenSettings;
  final ValueChanged<String>? onReport;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

enum _ArticleAction {
  mode,
  browser,
  read,
  save,
  contents,
  find,
  fullscreen,
  settings,
  report,
}

class _ArticleScreenState extends State<ArticleScreen> {
  final _scroll = ScrollController(keepScrollOffset: false);
  final _clock = Stopwatch()..start();
  final _targets = <int, GlobalKey>{};
  final _openFolds = <int>{};
  final _pullProgress = ValueNotifier<double>(0);
  late final AppLifecycleListener _lifecycle;
  late final Timer _periodic;
  late Future<ArticleDocument> _future;
  ModalRoute<dynamic>? _route;
  ArticleDocument? _document;
  OfflineArticle? _offlineArticle;
  WebViewController? _webController;
  String? _webError;
  bool _web = false;
  bool _webReady = false;
  bool _hasPreviousWebPage = false;
  bool _saved = false;
  bool _saving = false;
  bool _completed = false;
  bool _fullscreen = false;
  bool _restoring = true;
  bool _dirty = false;
  bool _trackingMove = false;
  bool _hapticSent = false;
  int? _pointer;
  int? _highlight;
  String _match = '';
  ArticleFootnote? _sideNote;
  int? _noteSource;
  bool _wideReader = false;
  int _activeUntil = 0;
  int _lastSample = 0;
  int _pendingActive = 0;
  int _loadGeneration = 0;
  double _nativePixels = 0;
  double _webPixels = 0;
  static const _readPull = 72.0;
  static const _pullDeadZone = 4.0;
  static const _idleMs = 90000;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed) {
          _flush();
          _activeUntil = 0;
        }
      },
    );
    _periodic = Timer.periodic(const Duration(seconds: 5), (_) => _flush());
    _resetContent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void didUpdateWidget(ArticleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content.key != widget.content.key ||
        oldWidget.offline != widget.offline) {
      _flush(
        content: oldWidget.content,
        offline: oldWidget.offline,
        publish: false,
      );
      _resetContent();
    }
  }

  void _resetContent() {
    final entry = widget.localStore
        .loadLibrary()
        .history
        .where((entry) => entry.content.key == widget.content.key)
        .firstOrNull;
    _completed = entry?.completed ?? false;
    _nativePixels =
        (widget.offline ? entry?.offlinePixelOffset : entry?.pixelOffset) ?? 0;
    _webPixels = entry?.webPixelOffset ?? 0;
    _openFolds.clear();
    _targets.clear();
    _document = null;
    _offlineArticle = null;
    _saved = widget.offline;
    _saving = false;
    _web = false;
    _webController = null;
    _webReady = false;
    _hasPreviousWebPage = false;
    _webError = null;
    _sideNote = null;
    _highlight = null;
    _match = '';
    _activeUntil = 0;
    _pendingActive = 0;
    _dirty = false;
    _restoring = true;
    _future = _load();
  }

  Future<ArticleDocument> _load() async {
    final generation = ++_loadGeneration;
    final content = widget.content;
    final store = await widget.repository.offlineArticles;
    final offline = widget.offline ? await store.read(content) : null;
    final document =
        offline?.document ?? await widget.repository.loadArticle(content);
    final saved = offline != null || await store.contains(content);
    if (mounted && generation == _loadGeneration) {
      setState(() {
        _document = document;
        _offlineArticle = offline;
        _saved = saved;
      });
      if (!_web) _markActivity();
      _dirty = true;
      // Publish outside the build that attaches the scroll view.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _loadGeneration) _flush();
      });
    }
    return document;
  }

  void _sampleActivity() {
    final now = _clock.elapsedMilliseconds;
    if ((_route?.isCurrent ?? true) &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
      _pendingActive += math.max(0, math.min(now, _activeUntil) - _lastSample);
    } else {
      _activeUntil = 0;
    }
    _lastSample = now;
  }

  void _markActivity() {
    _sampleActivity();
    _activeUntil = _lastSample + _idleMs;
  }

  void _flush({ContentRef? content, bool? offline, bool publish = true}) {
    _sampleActivity();
    if (!_dirty && _pendingActive == 0) return;
    final activity = _pendingActive;
    _pendingActive = 0;
    _dirty = false;
    final target = content ?? widget.content;
    final fromShelf = offline ?? widget.offline;
    final document = _document;
    final nativeProgress =
        _restoring ||
            !_scroll.hasClients ||
            !_scroll.position.hasContentDimensions
        ? null
        : _scroll.position.maxScrollExtent == 0
        ? 0.0
        : (_nativePixels / _scroll.position.maxScrollExtent).clamp(0.0, 1.0);
    final count = document?.blocks.length;
    final webProgress = _web && _webReady && _webPixels > 0
        ? (_webPixels / 220).ceil()
        : null;
    final snapshot = widget.localStore.recordRead(
      target,
      completed: _completed,
      blockCount: _web && webProgress != null
          ? math.max(count ?? 0, webProgress + 1)
          : count,
      scrollOffset: _completed && count != null
          ? count - 1
          : webProgress ??
                (count != null && nativeProgress != null
                    ? (nativeProgress * (count - 1)).round()
                    : null),
      pixelOffset: fromShelf ? null : _nativePixels,
      offlinePixelOffset: fromShelf ? _nativePixels : null,
      webPixelOffset: _webPixels,
      activeDeltaMs: activity,
    );
    unawaited(
      snapshot.then((library) {
        if (publish && mounted) widget.onLibraryChanged(library);
      }),
    );
  }

  void _changeCompletion() {
    setState(() => _completed = !_completed);
    _dirty = true;
    _flush();
  }

  void _restoreNative() {
    if (!_restoring) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_restoring || !_scroll.hasClients || _web) return;
      _scroll.jumpTo(
        _nativePixels.clamp(0.0, _scroll.position.maxScrollExtent),
      );
      _restoring = false;
    });
  }

  void _leave(VoidCallback go) {
    _flush();
    _activeUntil = 0;
    go();
  }

  void _toggleWeb() {
    _flush();
    if (_web) {
      _webController = null;
      setState(() {
        _web = false;
        _restoring = true;
        _hasPreviousWebPage = false;
      });
      if (_document != null) _markActivity();
      return;
    }
    final controller = WebViewController();
    _webController = controller;
    setState(() {
      _web = true;
      _webReady = false;
      _webError = null;
      _activeUntil = 0;
    });
    unawaited(_configureWeb(controller));
  }

  Future<void> _configureWeb(WebViewController controller) async {
    final initial = Uri.parse(articleUrlOf(widget.content.id));
    var restore = _webPixels.round();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri != null &&
              uri.scheme == 'https' &&
              uri.host == initial.host &&
              uri.userInfo.isEmpty) {
            return NavigationDecision.navigate;
          }
          if (uri != null &&
              request.isMainFrame &&
              (uri.scheme == 'https' || uri.scheme == 'http')) {
            unawaited(_openExternal(uri.toString()));
          }
          return NavigationDecision.prevent;
        },
        onPageStarted: (_) {
          if (!mounted || _webController != controller) return;
          _flush();
          _webReady = false;
          _activeUntil = 0;
          if (_webError != null) setState(() => _webError = null);
        },
        onWebResourceError: (error) {
          if (!mounted ||
              _webController != controller ||
              error.isForMainFrame != true) {
            return;
          }
          setState(() => _webError = error.description);
        },
        onPageFinished: (url) async {
          if (!mounted || _webController != controller || _webError != null) {
            return;
          }
          final previous = await controller.canGoBack();
          if (!mounted || _webController != controller) return;
          final current = Uri.tryParse(url);
          if (current?.path == initial.path) {
            if (restore > 0) await controller.scrollTo(0, restore);
            restore = 0;
            final position = await controller.getScrollPosition();
            if (!mounted || _webController != controller) return;
            _webPixels = position.dy;
          }
          setState(() {
            _hasPreviousWebPage = previous;
            _webReady = true;
          });
          _markActivity();
          _dirty = true;
        },
      ),
    );
    await controller.setOnScrollPositionChange((position) {
      if (!mounted || _webController != controller || !_webReady) return;
      if (!_hasPreviousWebPage) _webPixels = position.y;
      _markActivity();
      _dirty = true;
    });
    if (mounted && _webController == controller) {
      await controller.loadRequest(initial);
    }
  }

  Future<void> _openBrowser() async {
    final address =
        await _webController?.currentUrl() ?? articleUrlOf(widget.content.id);
    await _openExternal(address);
  }

  void _back() {
    if (_fullscreen) {
      setState(() {
        _fullscreen = false;
        _restoring = true;
      });
    } else if (_web && _hasPreviousWebPage) {
      unawaited(_webController!.goBack());
    } else {
      _leave(widget.onBack);
    }
  }

  @override
  void dispose() {
    _flush(publish: false);
    _periodic.cancel();
    _lifecycle.dispose();
    _pullProgress.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _saveOffline() async {
    final content = widget.content;
    setState(() => _saving = true);
    try {
      await widget.repository.saveOfflineArticle(content);
      if (!mounted || widget.content.key != content.key) return;
      setState(() => _saved = true);
      _message('离线副本已保存');
    } catch (error) {
      if (mounted && widget.content.key == content.key) {
        _message('无法保存离线副本：$error');
      }
    } finally {
      if (mounted && widget.content.key == content.key) {
        setState(() => _saving = false);
      }
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _pickAction(_ArticleAction action) {
    switch (action) {
      case _ArticleAction.mode:
        _toggleWeb();
      case _ArticleAction.browser:
        unawaited(_openBrowser());
      case _ArticleAction.read:
        _changeCompletion();
      case _ArticleAction.save:
        unawaited(_saveOffline());
      case _ArticleAction.contents:
        unawaited(_showContents());
      case _ArticleAction.find:
        unawaited(_find());
      case _ArticleAction.fullscreen:
        setState(() {
          _fullscreen = true;
          _restoring = true;
        });
      case _ArticleAction.settings:
        _leave(widget.onOpenSettings!);
      case _ArticleAction.report:
        _leave(
          () => widget.onReport!(
            _web
                ? 'web'
                : widget.offline
                ? 'offline'
                : 'native',
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final archive = SeedData.archiveAssetFor(widget.content.id);
    final body = _web ? _webBody() : _nativeBody();
    return PopScope(
      canPop: !_fullscreen && !(_web && _hasPreviousWebPage),
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _back();
      },
      child: _fullscreen
          ? Scaffold(
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(child: body),
                    Positioned(
                      top: 4,
                      right: 8,
                      child: IconButton.filledTonal(
                        tooltip: '退出全屏',
                        onPressed: _back,
                        icon: const Icon(Icons.fullscreen_exit),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : DetailCanvas(
              onBack: _back,
              title: widget.content.title,
              subtitle: widget.content.id,
              actions: [
                if (archive != null)
                  IconButton(
                    tooltip: '三维档案',
                    icon: const Icon(Icons.view_in_ar_outlined),
                    onPressed: () =>
                        _leave(() => widget.onOpenArchive(archive)),
                  ),
                IconButton(
                  tooltip: widget.favorite ? '取消收藏' : '收藏',
                  icon: Icon(widget.favorite ? Icons.star : Icons.star_outline),
                  onPressed: widget.onToggleFavorite,
                ),
                PopupMenuButton<_ArticleAction>(
                  tooltip: '阅读菜单',
                  onSelected: _pickAction,
                  itemBuilder: (_) => [
                    if (!widget.offline)
                      PopupMenuItem(
                        value: _ArticleAction.mode,
                        child: Text(_web ? '切换到原生阅读' : '切换到原版网页'),
                      ),
                    PopupMenuItem(
                      value: _ArticleAction.browser,
                      enabled: !widget.offline,
                      child: const Text('在浏览器中打开'),
                    ),
                    if (_web)
                      PopupMenuItem(
                        value: _ArticleAction.read,
                        child: Text(_completed ? '取消已读' : '标为已读'),
                      ),
                    if (!_web && _document != null) ...[
                      const PopupMenuItem(
                        value: _ArticleAction.contents,
                        child: Text('目录与脚注'),
                      ),
                      const PopupMenuItem(
                        value: _ArticleAction.find,
                        child: Text('文内查找'),
                      ),
                    ],
                    if (!widget.offline)
                      PopupMenuItem(
                        value: _ArticleAction.save,
                        enabled: !_saving,
                        child: Text(
                          _saving
                              ? '正在保存…'
                              : _saved
                              ? '更新离线副本'
                              : '保存离线副本',
                        ),
                      ),
                    const PopupMenuItem(
                      value: _ArticleAction.fullscreen,
                      child: Text('全屏阅读'),
                    ),
                    if (widget.onOpenSettings != null)
                      const PopupMenuItem(
                        value: _ArticleAction.settings,
                        child: Text('阅读设置'),
                      ),
                    if (widget.onReport != null)
                      const PopupMenuItem(
                        value: _ArticleAction.report,
                        child: Text('上报档案异常'),
                      ),
                  ],
                ),
              ],
              child: body,
            ),
    );
  }

  Widget _webBody() {
    if (_webError case final error?) {
      return ArticleError(
        message: error,
        onRetry: () => _webController!.reload(),
        onOpenOriginal: _openBrowser,
      );
    }
    return WebViewWidget(controller: _webController!);
  }

  Widget _nativeBody() => FutureBuilder<ArticleDocument>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return ArticleError(
          message: snapshot.error.toString(),
          onRetry: () => setState(() => _future = _load()),
          onOpenOriginal: widget.offline ? null : _toggleWeb,
        );
      }
      final document = snapshot.requireData;
      _restoreNative();
      return LayoutBuilder(
        builder: (context, constraints) {
          _wideReader = constraints.maxWidth >= 800;
          return Row(
            children: [
              Expanded(child: _readerList(document)),
              if (_wideReader && _sideNote != null)
                SizedBox(
                  width: 280,
                  child: _footnotePanel(_sideNote!, side: true),
                ),
            ],
          );
        },
      );
    },
  );

  Widget _readerList(ArticleDocument document) => Listener(
    onPointerDown: (event) {
      if (_pointer != null) return;
      _pointer = event.pointer;
      _markActivity();
    },
    onPointerMove: (event) {
      if (_pointer != event.pointer || !_scroll.hasClients) return;
      final delta = -event.delta.dy;
      if (delta > 0 && !_trackingMove && _scroll.position.extentAfter <= 0.5) {
        _trackingMove = true;
      }
      if (!_trackingMove) return;
      _pullProgress.value = (_pullProgress.value + delta).clamp(
        0.0,
        _readPull + _pullDeadZone,
      );
      if (_pullProgress.value >= _readPull + _pullDeadZone && !_hapticSent) {
        _hapticSent = true;
        if (widget.settings.hapticEnabled) {
          unawaited(HapticFeedback.selectionClick());
        }
      }
    },
    onPointerUp: (event) => _finishPull(event.pointer, cancelled: false),
    onPointerCancel: (event) => _finishPull(event.pointer, cancelled: true),
    child: NotificationListener<ScrollNotification>(
      onNotification: (note) {
        if (_restoring ||
            note.depth != 0 ||
            note is! ScrollUpdateNotification) {
          return false;
        }
        _nativePixels = note.metrics.pixels.clamp(
          0.0,
          note.metrics.maxScrollExtent,
        );
        _dirty = true;
        if (note.dragDetails != null) _markActivity();
        return false;
      },
      child: SingleChildScrollView(
        key: ValueKey(document),
        controller: _scroll,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.offline ? '永久离线副本' : '原生阅读',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < document.blocks.length; i++) ...[
                  for (final fold
                      in document.folds
                          .where((f) => f.start == i)
                          .toList()
                          .reversed)
                    if (!_foldHiddenByParent(document, fold))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: Icon(
                            _openFolds.contains(document.folds.indexOf(fold))
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          label: Text(fold.label),
                          onPressed: () => setState(() {
                            final index = document.folds.indexOf(fold);
                            if (!_openFolds.remove(index)) {
                              _openFolds.add(index);
                            }
                          }),
                        ),
                      ),
                  if (!_isFolded(document, i))
                    Padding(
                      key: _targets.putIfAbsent(i, GlobalKey.new),
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _block(document, i),
                    ),
                ],
                const SizedBox(height: 16),
                Text(
                  _completed ? '已读 · 上拉取消已读' : '文末 · 继续上拉标为已读',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<double>(
                  valueListenable: _pullProgress,
                  builder: (context, value, _) {
                    return Opacity(
                      opacity: value > _pullDeadZone ? 1 : 0,
                      child: LinearProgressIndicator(
                        value: ((value - _pullDeadZone) / _readPull).clamp(
                          0.0,
                          1.0,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  bool _foldHiddenByParent(ArticleDocument doc, ArticleFold fold) =>
      doc.folds.indexed.any((entry) {
        final outer = entry.$2;
        return outer != fold &&
            outer.start <= fold.start &&
            outer.end >= fold.end &&
            entry.$1 > doc.folds.indexOf(fold) &&
            !_openFolds.contains(entry.$1);
      });

  bool _isFolded(ArticleDocument doc, int index) => doc.folds.indexed.any(
    (entry) =>
        index >= entry.$2.start &&
        index < entry.$2.end &&
        !_openFolds.contains(entry.$1),
  );

  void _finishPull(int pointer, {required bool cancelled}) {
    if (_pointer != pointer) return;
    final armed = _pullProgress.value >= _readPull + _pullDeadZone;
    _pointer = null;
    _trackingMove = false;
    _hapticSent = false;
    _pullProgress.value = 0;
    if (armed &&
        !cancelled &&
        _scroll.hasClients &&
        _scroll.position.extentAfter <= 0.5) {
      _changeCompletion();
    }
  }

  Widget _block(ArticleDocument document, int index) {
    final theme = Theme.of(context);
    final body = TextStyle(
      fontSize: widget.settings.fontSize,
      height: widget.settings.lineHeightMultiple,
      color: theme.colorScheme.onSurface,
    );
    Widget text(String value, TextStyle style) {
      final links = document.links[index];
      if (links == null) {
        return Text.rich(TextSpan(children: _textSpans(value)), style: style);
      }
      final spans = <InlineSpan>[];
      var start = 0;
      for (final link in links) {
        spans.addAll(_textSpans(value.substring(start, link.offset)));
        final note = document.footnotes[link.target.fragment];
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InkWell(
              onTap: () => note == null
                  ? _followLink(document, link)
                  : _showNote(note, index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  link.text,
                  style: style.copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                    fontSize: note == null
                        ? style.fontSize
                        : (style.fontSize ?? 16) * 0.78,
                  ),
                ),
              ),
            ),
          ),
        );
        start = link.offset + link.text.length;
      }
      spans.addAll(_textSpans(value.substring(start)));
      return Text.rich(TextSpan(children: spans), style: style);
    }

    final content = switch (document.blocks[index]) {
      ArticleHeading(text: final value, :final level) => _heading(
        value,
        level,
        body,
        text,
      ),
      ArticleParagraph(text: final value) => text(value, body),
      ArticleQuote(text: final value) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: text(value, body),
        ),
      ),
      ArticleListBlock(:final items, :final ordered) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, value) in items.indexed)
            Text('${ordered ? '${i + 1}.' : '•'} $value', style: body),
        ],
      ),
      ArticleImage image => _ReaderImage(
        image: image,
        repository: widget.repository,
        offline: _offlineArticle,
      ),
      ArticleDivider() => const Divider(),
    };
    return _highlight == index
        ? ColoredBox(
            color: theme.colorScheme.secondaryContainer,
            child: content,
          )
        : content;
  }

  Widget _heading(
    String text,
    int level,
    TextStyle body,
    Widget Function(String, TextStyle) render,
  ) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: render(
      text,
      body.copyWith(
        fontSize: (body.fontSize ?? 16) + (level <= 2 ? 7 : 3),
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  List<TextSpan> _textSpans(String value) {
    if (_match.isEmpty) return [TextSpan(text: value)];
    final matches = RegExp(
      RegExp.escape(_match),
      caseSensitive: false,
    ).allMatches(value);
    final output = <TextSpan>[];
    var start = 0;
    final scheme = Theme.of(context).colorScheme;
    for (final match in matches) {
      output.add(TextSpan(text: value.substring(start, match.start)));
      output.add(
        TextSpan(
          text: value.substring(match.start, match.end),
          style: TextStyle(
            color: scheme.onTertiaryContainer,
            backgroundColor: scheme.tertiaryContainer,
          ),
        ),
      );
      start = match.end;
    }
    return [...output, TextSpan(text: value.substring(start))];
  }

  void _followLink(ArticleDocument doc, ArticleInlineLink link) {
    final target = link.target;
    final base = Uri.parse(doc.sourceUrl);
    if (target.origin == base.origin &&
        target.path == base.path &&
        target.hasFragment) {
      final index = doc.anchors[target.fragment];
      if (index != null) _locate(index);
      return;
    }
    final openContent = widget.onOpenContent;
    if (openContent != null &&
        target.origin == base.origin &&
        target.pathSegments.length == 1 &&
        target.pathSegments.single.isNotEmpty) {
      final id = target.pathSegments.single;
      _leave(
        () => openContent(
          ContentRef.create(
            id.startsWith('scp-') ? ContentKind.scp : ContentKind.wiki,
            id,
            link.text,
          ),
        ),
      );
    } else {
      unawaited(_openExternal(target.toString()));
    }
  }

  void _locate(int index, {String match = ''}) {
    final doc = _document!;
    if (index >= doc.blocks.length) return;
    setState(() {
      _highlight = index;
      _match = match;
      for (final (foldIndex, fold) in doc.folds.indexed) {
        if (index >= fold.start && index < fold.end) _openFolds.add(foldIndex);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _targets[index]?.currentContext;
      if (!mounted || target == null) return;
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: 0.15,
          duration: const Duration(milliseconds: 220),
        ),
      );
    });
  }

  void _showNote(ArticleFootnote note, int source) {
    _noteSource = source;
    if (_wideReader && !_fullscreen) {
      setState(() => _sideNote = note);
    } else {
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => FractionallySizedBox(
            heightFactor: 0.6,
            child: _footnotePanel(note, side: false),
          ),
        ),
      );
    }
  }

  Widget _footnotePanel(ArticleFootnote note, {required bool side}) => Builder(
    builder: (context) => Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '脚注 ${note.label}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (side)
                  IconButton(
                    tooltip: '关闭脚注',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _sideNote = null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              note.text,
              style: TextStyle(
                fontSize: widget.settings.fontSize,
                height: widget.settings.lineHeightMultiple,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                if (!side) Navigator.of(context).pop();
                _locate(_noteSource!);
              },
              child: const Text('返回正文位置'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _showContents() async {
    final doc = _document!;
    final index = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final (index, block) in doc.blocks.indexed)
            if (block is ArticleHeading)
              ListTile(
                title: Text(block.text),
                onTap: () => Navigator.pop(context, index),
              ),
          for (final note in doc.footnotes.values)
            ListTile(
              title: Text('脚注 ${note.label}'),
              subtitle: Text(
                note.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                final source = doc.links.entries
                    .where(
                      (entry) => entry.value.any(
                        (link) => link.target.fragment == note.id,
                      ),
                    )
                    .firstOrNull;
                Navigator.pop(context, source?.key);
                if (source != null) _showNote(note, source.key);
              },
            ),
          if (doc.footnotes.isEmpty &&
              !doc.blocks.any((block) => block is ArticleHeading))
            const ListTile(title: Text('这篇文章没有目录或脚注')),
        ],
      ),
    );
    if (mounted && index != null) _locate(index);
  }

  Future<void> _find() async {
    var query = '';
    final term = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文内查找'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => query = value,
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
          decoration: const InputDecoration(hintText: '输入关键词'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, query.trim()),
            child: const Text('查找'),
          ),
        ],
      ),
    );
    if (!mounted || term == null || term.isEmpty) return;
    final doc = _document!;
    final regex = RegExp(RegExp.escape(term), caseSensitive: false);
    final results = <(int, String)>[];
    for (final (index, block) in doc.blocks.indexed) {
      final value = switch (block) {
        ArticleHeading(:final text) ||
        ArticleParagraph(:final text) ||
        ArticleQuote(:final text) => text,
        ArticleListBlock(:final items) => items.join(' '),
        ArticleImage(:final caption) => caption,
        ArticleDivider() => '',
      };
      final hit = regex.firstMatch(value);
      if (hit != null) {
        results.add((
          index,
          value.substring(
            math.max(0, hit.start - 25),
            math.min(value.length, hit.end + 65),
          ),
        ));
      }
    }
    if (results.isEmpty) {
      _message('文内没有匹配项');
    } else if (results.length == 1) {
      _locate(results.single.$1, match: term);
    } else {
      final index = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (context) => ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, i) => ListTile(
            title: Text(results[i].$2),
            onTap: () => Navigator.pop(context, results[i].$1),
          ),
        ),
      );
      if (mounted && index != null) _locate(index, match: term);
    }
  }
}

class _ReaderImage extends StatefulWidget {
  const _ReaderImage({
    required this.image,
    required this.repository,
    required this.offline,
  });

  final ArticleImage image;
  final AnomiconRepository repository;
  final OfflineArticle? offline;

  @override
  State<_ReaderImage> createState() => _ReaderImageState();
}

class _ReaderImageState extends State<_ReaderImage> {
  late final Future<ImageProvider> _image = _load();

  Future<ImageProvider> _load() async {
    if (widget.offline case final copy?) {
      return MemoryImage(copy.images[widget.image.url]!);
    }
    return FileImage(await widget.repository.loadImageFile(widget.image.url));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ImageProvider>(
    future: _image,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Text(widget.image.alt.isEmpty ? '图片暂时不可用' : widget.image.alt);
      }
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final image = snapshot.requireData;
      final scheme = Theme.of(context).colorScheme;
      return Column(
        children: [
          InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  title: const Text('图片预览'),
                  leading: IconButton(
                    tooltip: '关闭图片',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
                body: SizedBox.expand(
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Image(image: image, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            child: Image(
              image: image,
              semanticLabel: widget.image.alt,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Text(widget.image.alt.isEmpty ? '图片暂时不可用' : widget.image.alt),
            ),
          ),
          if (widget.image.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                widget.image.caption,
                style: TextStyle(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
    },
  );
}

class ArticleError extends StatelessWidget {
  const ArticleError({
    required this.message,
    required this.onRetry,
    this.onOpenOriginal,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onOpenOriginal;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(onPressed: onRetry, child: const Text('重试')),
              if (onOpenOriginal != null)
                OutlinedButton(
                  onPressed: onOpenOriginal,
                  child: const Text('原版网页'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class OfflineShelfScreen extends StatefulWidget {
  const OfflineShelfScreen({
    required this.repository,
    required this.onBack,
    required this.onOpenContent,
    super.key,
  });

  final AnomiconRepository repository;
  final VoidCallback onBack;
  final ValueChanged<ContentRef> onOpenContent;

  @override
  State<OfflineShelfScreen> createState() => _OfflineShelfScreenState();
}

class _OfflineShelfScreenState extends State<OfflineShelfScreen> {
  late Future<List<OfflineArticleInfo>> _future = _load();
  final _working = <String>{};

  Future<List<OfflineArticleInfo>> _load() async =>
      (await widget.repository.offlineArticles).list();

  Future<void> _operate(ContentRef content, {required bool remove}) async {
    if (remove) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('移除离线副本？'),
          content: Text(content.title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('移除'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    setState(() => _working.add(content.key));
    try {
      if (remove) {
        await (await widget.repository.offlineArticles).remove(content);
      } else {
        await widget.repository.saveOfflineArticle(content);
      }
      if (mounted) setState(() => _future = _load());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _working.remove(content.key));
    }
  }

  @override
  Widget build(BuildContext context) => DetailCanvas(
    onBack: widget.onBack,
    title: '离线书架',
    subtitle: '永久离线副本',
    child: FutureBuilder<List<OfflineArticleInfo>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ArticleError(
            message: snapshot.error.toString(),
            onRetry: () => setState(() => _future = _load()),
          );
        }
        final entries = snapshot.requireData;
        if (entries.isEmpty) {
          return const Center(child: Text('还没有离线副本。可从阅读菜单保存档案。'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            final busy = _working.contains(entry.content.key);
            final date = MaterialLocalizations.of(context)
                .formatShortDate(entry.savedAt);
            return ListTile(
              leading: const Icon(Icons.offline_pin_outlined),
              title: Text(entry.content.title),
              subtitle: Text('${entry.content.id.toUpperCase()} · $date'),
              onTap: () => widget.onOpenContent(entry.content),
              trailing: busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : PopupMenuButton<bool>(
                      tooltip: '副本操作',
                      onSelected: (remove) =>
                          _operate(entry.content, remove: remove),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: false, child: Text('更新副本')),
                        PopupMenuItem(value: true, child: Text('移除副本')),
                      ],
                    ),
            );
          },
        );
      },
    ),
  );
}
