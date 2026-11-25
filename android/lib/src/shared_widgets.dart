part of 'anomicon_app.dart';

class PageCanvas extends StatelessWidget {
  const PageCanvas({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _black,
      child: SafeArea(bottom: false, child: child),
    );
  }
}

class DetailCanvas extends StatelessWidget {
  const DetailCanvas({
    required this.onBack,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const <Widget>[],
    super.key,
  });

  final VoidCallback onBack;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: <Widget>[
                  GlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    label: '返回',
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(color: _muted, fontSize: 18),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    this.subtitle,
    this.trailing,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: compact
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 30 : 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(color: _muted, fontSize: 17),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: _muted,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class GlassBottomBar extends StatelessWidget {
  const GlassBottomBar({
    required this.selectedTab,
    required this.onSelectTab,
    super.key,
  });

  final HomeTab selectedTab;
  final ValueChanged<HomeTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(44),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: math.min(MediaQuery.sizeOf(context).width - 72, 580),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: _surfaceHigh.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(44),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: HomeTab.values.map((tab) {
              final selected = tab == selectedTab;
              return InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => onSelectTab(tab),
                child: SizedBox(
                  width: 62,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        tab.icon,
                        size: 28,
                        color: selected ? _accent : _muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.title,
                        style: TextStyle(
                          color: selected ? _accent : _muted,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: _surfaceLow.withValues(alpha: 0.86),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Icon(icon, size: 34, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color = _surface,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}

class HorizontalPills extends StatelessWidget {
  const HorizontalPills({
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.horizontalPadding = 20,
    super.key,
  });

  final Map<String, String> labels;
  final String selected;
  final ValueChanged<String> onSelected;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        itemBuilder: (context, index) {
          final entry = labels.entries.elementAt(index);
          final active = entry.key == selected;
          return ChoiceChip(
            selected: active,
            showCheckmark: false,
            label: Text(entry.value),
            labelStyle: TextStyle(
              color: active ? Colors.white : const Color(0xFFC1C4C7),
              fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              fontSize: 18,
            ),
            selectedColor: _accent,
            backgroundColor: _surfaceLow,
            side: BorderSide(
              color: Colors.white.withValues(alpha: active ? 0 : 0.12),
            ),
            shape: const StadiumBorder(),
            onSelected: (_) => onSelected(entry.key),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 10),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: _surfaceLow,
      child: Column(
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 17),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class HintRow extends StatelessWidget {
  const HintRow({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, color: _muted, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _muted, fontSize: 16, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openExternal(String url) async {
  if (url.trim().isEmpty) return;
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
