import 'package:html/parser.dart' as html;

/// Extracts the first article image using the same content region and
/// decoration exclusions as the HarmonyOS catalog preview.
Uri? parseWikiPreviewImage(String source, Uri page) {
  final content = html.parse(source).getElementById('page-content');
  if (content == null) return null;
  for (final image in content.querySelectorAll('img[src]')) {
    final src = image.attributes['src']!.trim();
    if (src.isEmpty ||
        image.classes.contains('small') ||
        _decorativeImage.hasMatch(src)) {
      continue;
    }
    final width = int.tryParse(image.attributes['width'] ?? '');
    final height = int.tryParse(image.attributes['height'] ?? '');
    if (width != null && height != null && width <= 96 && height <= 96) {
      continue;
    }
    final reference = Uri.tryParse(src);
    if (reference == null) continue;
    final resolved = page.resolveUri(reference);
    if (resolved.host.isEmpty || resolved.userInfo.isNotEmpty) continue;
    if (resolved.scheme == 'https') return resolved;
    if (resolved.scheme == 'http') return resolved.replace(scheme: 'https');
  }
  return null;
}

final _decorativeImage = RegExp(
  r'avatar\.php|userkarma\.php|/avatar|/rating|icon|logo|printer|license|'
  r'/component(?::|%3a)|classified-(?:bar|decoration)|/local--files/theme(?::|%3a)',
  caseSensitive: false,
);
