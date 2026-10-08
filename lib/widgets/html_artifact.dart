import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';
import '../util/html_frame.dart';
import 'markdown_text.dart' show CodeBlock;
import 'spinner.dart';

/// A picture made in this chat, by the name the chat shows and where it
/// really is.
@immutable
class PageAsset {
  const PageAsset(this.name, this.url);

  final String name;
  final String url;

  @override
  bool operator ==(Object other) =>
      other is PageAsset && other.name == name && other.url == url;

  @override
  int get hashCode => Object.hash(name, url);
}

/// The pictures made in the thread, oldest first, for the pages in it to
/// use. A model asked for a page "using that pink flower image" knows the
/// picture by its file name, or by the suite.shiftai.club/r/… link drawn
/// on it, rarely by where the file is; the page drew a blank where the
/// picture should have been.
class PageAssets extends InheritedWidget {
  const PageAssets({required this.assets, required super.child, super.key});

  final List<PageAsset> assets;

  static List<PageAsset> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageAssets>()?.assets ??
      const <PageAsset>[];

  @override
  bool updateShouldNotify(PageAssets old) => !listEquals(old.assets, assets);
}

/// A web page a model wrote, shown as the page: a live preview in the
/// thread, full screen on a tap, and its code to copy or save.
///
/// The chat showed a page as a wall of HTML source, so "build me a
/// website" could only ever come back as code to paste somewhere else.
class HtmlArtifact extends StatefulWidget {
  const HtmlArtifact({required this.html, super.key});

  final String html;

  /// Whether a code block is a page to show rather than code to read: a
  /// whole document, or HTML long enough to be more than an example.
  static bool isPage(String code, String lang) {
    final String start = code.trimLeft().toLowerCase();
    if (start.startsWith('<!doctype html') || start.startsWith('<html')) {
      return true;
    }
    if (lang != 'html' && lang != 'htm') return false;
    final String all = code.toLowerCase();
    return all.contains('<body') ||
        all.contains('<head') ||
        all.contains('<style') ||
        code.length > 600;
  }

  /// The page's own `<title>`, or a plain name.
  static String titleOf(String html) {
    final RegExpMatch? m = RegExp(
      r'<title[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    final String title =
        _decode(m?.group(1) ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return title.isEmpty ? 'Web page' : title;
  }

  /// The entities a title is written with: "Petal &amp; Pink" is
  /// "Petal & Pink".
  static String _decode(String text) => text
      .replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]+);'), (Match m) {
        final int? code =
            int.tryParse(m.group(2)!, radix: m.group(1)!.isEmpty ? 10 : 16);
        return code == null ? m.group(0)! : String.fromCharCode(code);
      })
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&');

  /// [html] with the chat's pictures where it points at them.
  ///
  /// A reference (an `src`, a `poster`, a CSS `url(...)`) that names one
  /// of [assets] by file name, or by the id in it ("1c97aaa8", which the
  /// picture's own link carries), becomes that picture's address. A bare
  /// picture file the chat has no picture by ("pink-flower.jpg", on no
  /// server) is the newest picture: the one the page was asked to use.
  /// Addresses that are already real, and `data:` pictures, are left be.
  static String withAssets(String html, List<PageAsset> assets) {
    if (assets.isEmpty) return html;
    String? real(String ref) {
      final String r = ref.trim();
      if (r.isEmpty || r.startsWith('data:') || r.startsWith('#')) {
        return null;
      }
      if (assets.any((PageAsset a) => a.url == r)) return null;
      final String low = r.toLowerCase();
      for (final PageAsset a in assets.reversed) {
        if (_namesOf(a.name).any(low.contains)) return a.url;
      }
      final bool relative = !RegExp(
        r'^(?:[a-z][a-z0-9+.-]*:|//)',
        caseSensitive: false,
      ).hasMatch(r);
      final bool picture = RegExp(
        r'\.(?:png|jpe?g|webp|gif|avif)(?:[?#].*)?$',
        caseSensitive: false,
      ).hasMatch(r);
      return relative && picture ? assets.last.url : null;
    }

    return html.replaceAllMapped(
      RegExp(
        r'''(\b(?:src|poster)\s*=\s*)(["'])(.*?)\2''',
        caseSensitive: false,
      ),
      (Match m) {
        final String? to = real(m.group(3)!);
        return to == null ? m.group(0)! : '${m[1]}${m[2]}$to${m[2]}';
      },
    ).replaceAllMapped(
      RegExp(r'''url\(\s*(["']?)([^"')]*)\1\s*\)''', caseSensitive: false),
      (Match m) {
        final String? to = real(m.group(2)!);
        return to == null ? m.group(0)! : "url('$to')";
      },
    );
  }

  /// What a picture can be named by in a page: its file name, that
  /// without the extension, and the id in it.
  static List<String> _namesOf(String fileName) {
    final String name = fileName.trim().toLowerCase();
    final int dot = name.lastIndexOf('.');
    final String stem = dot > 0 ? name.substring(0, dot) : name;
    return <String>[
      if (name.length >= 6) name,
      if (stem.length >= 6) stem,
      for (final Match m in RegExp(r'[0-9a-f]{6,}').allMatches(stem))
        if (RegExp(r'[0-9]').hasMatch(m.group(0)!)) m.group(0)!,
    ];
  }

  /// A name to save it under: the title, made safe for a file.
  static String fileNameOf(String html) {
    final String slug = titleOf(html)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${slug.isEmpty ? 'page' : slug}.html';
  }

  @override
  State<HtmlArtifact> createState() => _HtmlArtifactState();
}

class _HtmlArtifactState extends State<HtmlArtifact> {
  /// The page as shown, copied and saved: with the chat's pictures in it.
  String get _page => HtmlArtifact.withAssets(
        widget.html,
        PageAssets.of(context),
      );

  bool _showCode = false;

  /// Off the web there is no preview, so the code shows unless hidden.
  bool get _codeShown => _showCode != !canShowHtml;

  void _copy() {
    Clipboard.setData(ClipboardData(text: _page));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Page code copied')),
    );
  }

  void _download() => downloadHtml(HtmlArtifact.fileNameOf(widget.html), _page);

  void _open() => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (BuildContext _) => _PageScreen(
            html: _page,
            onCopy: _copy,
            onDownload: _download,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final int lines = '\n'.allMatches(widget.html).length + 1;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.lgAll,
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.x4,
              Space.x3,
              Space.x4,
              Space.x3,
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.language_rounded, size: 20, color: c.accent),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        HtmlArtifact.titleOf(widget.html),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShiftType.bodyStrong(c.text),
                      ),
                      Text(
                        'Website · $lines lines',
                        style: ShiftType.caption(c.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (canShowHtml)
            Semantics(
              button: true,
              label: 'Open the page',
              child: GestureDetector(
                onTap: _open,
                child: SizedBox(
                  height: 380,
                  child: AbsorbPointer(
                    child: htmlFrame(_page, interactive: false),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x4,
                0,
                Space.x4,
                Space.x2,
              ),
              child: Text(
                'Open ShiftAi on the web to see this page. Its code is '
                'below to copy and use anywhere.',
                style: ShiftType.caption(c.textMuted),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x2),
            child: Wrap(
              children: <Widget>[
                if (canShowHtml)
                  _Action(
                    icon: Icons.open_in_full_rounded,
                    label: 'Open',
                    onPressed: _open,
                  ),
                _Action(
                  icon: Icons.content_copy_rounded,
                  label: 'Copy code',
                  onPressed: _copy,
                ),
                if (canShowHtml)
                  _Action(
                    icon: Icons.download_rounded,
                    label: 'Download',
                    onPressed: _download,
                  ),
                _Action(
                  icon: Icons.code_rounded,
                  label: _codeShown ? 'Hide code' : 'View code',
                  onPressed: () => setState(() => _showCode = !_showCode),
                ),
              ],
            ),
          ),
          if (_codeShown)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x3,
                0,
                Space.x3,
                Space.x3,
              ),
              child: CodeBlock(code: _page),
            ),
        ],
      ),
    );
  }
}

/// While the page is still being written: how far it has got, rather than
/// the source scrolling past.
class HtmlArtifactBuilding extends StatelessWidget {
  const HtmlArtifactBuilding({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final int lines = '\n'.allMatches(code).length + 1;
    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.lgAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: <Widget>[
          ShiftSpinner(color: c.textMuted),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Text(
              'Building the page… $lines lines so far',
              style: ShiftType.bodySm(c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: c.textMuted),
      label: Text(label, style: ShiftType.caption(c.textMuted)),
    );
  }
}

/// The page full screen, to use it: links, buttons and scrolling work.
class _PageScreen extends StatelessWidget {
  const _PageScreen({
    required this.html,
    required this.onCopy,
    required this.onDownload,
  });

  final String html;
  final VoidCallback onCopy;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          icon: Icon(Icons.close_rounded, color: c.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          HtmlArtifact.titleOf(html),
          style: ShiftType.headline(c.text),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Copy code',
            icon: Icon(Icons.content_copy_rounded, color: c.text),
            onPressed: onCopy,
          ),
          IconButton(
            tooltip: 'Download',
            icon: Icon(Icons.download_rounded, color: c.text),
            onPressed: onDownload,
          ),
        ],
      ),
      body: SafeArea(child: htmlFrame(html, interactive: true)),
    );
  }
}
