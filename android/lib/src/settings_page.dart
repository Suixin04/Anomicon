part of 'anomicon_app.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.settings,
    required this.onBack,
    required this.onSettingsChange,
    required this.onHaptic,
    this.onOpenArchiveGallery,
    this.onOpenOffline,
    super.key,
  });

  final AppSettings settings;
  final VoidCallback onBack;
  final ValueChanged<AppSettings> onSettingsChange;
  final VoidCallback onHaptic;
  final VoidCallback? onOpenArchiveGallery;
  final VoidCallback? onOpenOffline;

  Future<void> _clearSearchHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空搜索历史？'),
        content: const Text('本机保存的搜索词将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DiscoveryHistory.clear();
    } on FileSystemException catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    if (context.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('搜索历史已清空')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailCanvas(
      onBack: onBack,
      title: '设置',
      subtitle: '阅读与平台反馈',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 44),
        children: <Widget>[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '主题',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                HorizontalPills(
                  labels: const <String, String>{
                    'system': '跟随系统',
                    'light': '浅色',
                    'dark': '深色',
                  },
                  selected: settings.themeMode.name,
                  onSelected: (value) {
                    onHaptic();
                    onSettingsChange(
                      settings.copyWith(
                        themeMode: ThemeModePreference.values.firstWhere(
                          (item) => item.name == value,
                        ),
                      ),
                    );
                  },
                  horizontalPadding: 0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: <Widget>[
                SettingSwitchRow(
                  title: '触感反馈',
                  subtitle: '切换页面或操作按钮时提供触感反馈。',
                  value: settings.hapticEnabled,
                  onChanged: (value) {
                    onHaptic();
                    onSettingsChange(settings.copyWith(hapticEnabled: value));
                  },
                ),
                const Divider(),
                SettingSwitchRow(
                  title: '沉浸材质',
                  subtitle: '为导航栏和详情标题栏应用更明显的背景层次。',
                  value: settings.immersiveMaterialEnabled,
                  onChanged: (value) {
                    onHaptic();
                    onSettingsChange(
                      settings.copyWith(immersiveMaterialEnabled: value),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: <Widget>[
                SettingSliderRow(
                  title: '阅读字号',
                  valueLabel: '${settings.fontSize.round()}sp',
                  value: settings.fontSize,
                  min: ReadingSettingsRange.minFontSize,
                  max: ReadingSettingsRange.maxFontSize,
                  onChanged: (value) =>
                      onSettingsChange(settings.copyWith(fontSize: value)),
                ),
                const SizedBox(height: 18),
                SettingSliderRow(
                  title: '阅读行距',
                  valueLabel:
                      '${settings.lineHeightMultiple.toStringAsFixed(1)}x',
                  value: settings.lineHeightMultiple,
                  min: ReadingSettingsRange.minLineHeight,
                  max: ReadingSettingsRange.maxLineHeight,
                  onChanged: (value) => onSettingsChange(
                    settings.copyWith(lineHeightMultiple: value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('清空搜索历史'),
              onTap: () => _clearSearchHistory(context),
            ),
          ),
          if (onOpenOffline != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.offline_pin_outlined),
                title: const Text('离线书架'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenOffline,
              ),
            ),
          ],
          if (onOpenArchiveGallery != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.view_in_ar_outlined),
                title: const Text('三维档案馆'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenArchiveGallery,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingSwitchRow extends StatelessWidget {
  const SettingSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class SettingSliderRow extends StatelessWidget {
  const SettingSliderRow({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueLabel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
