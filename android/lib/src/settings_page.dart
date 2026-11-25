part of 'anomicon_app.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.settings,
    required this.onBack,
    required this.onSettingsChange,
    required this.onHaptic,
    super.key,
  });

  final AppSettings settings;
  final VoidCallback onBack;
  final ValueChanged<AppSettings> onSettingsChange;
  final VoidCallback onHaptic;

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
                  subtitle: '保留 HarmonyOS 版本中的触感开关语义。',
                  value: settings.hapticEnabled,
                  onChanged: (value) {
                    onHaptic();
                    onSettingsChange(settings.copyWith(hapticEnabled: value));
                  },
                ),
                const Divider(color: Color(0xFF3F4448)),
                SettingSwitchRow(
                  title: '沉浸材质',
                  subtitle: '保持黑底、半透明底栏和系统栏沉浸效果。',
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
                  style: const TextStyle(color: _muted, height: 1.35),
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
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              valueLabel,
              style: const TextStyle(
                color: _accent,
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
