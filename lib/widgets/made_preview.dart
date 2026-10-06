import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';
import 'common.dart';
import 'spinner.dart';

/// What draws a picture from a link: the network, or the bytes themselves
/// when the engine sends the picture inline as a `data:` URL, which
/// `NetworkImage` cannot fetch on a phone.
ImageProvider pictureFrom(String url) {
  if (url.startsWith('data:')) {
    try {
      final Uint8List bytes = UriData.parse(url).contentAsBytes();
      return MemoryImage(bytes);
    } on FormatException {
      // Drawn as a link below, which fails and says so.
    }
  }
  return NetworkImage(url);
}

/// One picture from [url], as [Image] draws it.
///
/// On the web a file from another host that does not allow it (no
/// `Access-Control-Allow-Origin`) cannot be drawn on the canvas; with
/// [WebHtmlElementStrategy.fallback] it is shown as an `<img>` instead,
/// the way any web page would show it. Made files often live on the
/// model provider's own storage, which never sends that header.
Widget networkPicture(
  String url, {
  BoxFit fit = BoxFit.cover,
  ImageLoadingBuilder? loadingBuilder,
  ImageFrameBuilder? frameBuilder,
  ImageErrorWidgetBuilder? errorBuilder,
}) =>
    url.startsWith('data:')
        ? Image(
            image: pictureFrom(url),
            fit: fit,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            frameBuilder: frameBuilder,
            errorBuilder: errorBuilder,
          )
        : Image.network(
            url,
            fit: fit,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            loadingBuilder: loadingBuilder,
            frameBuilder: frameBuilder,
            errorBuilder: errorBuilder,
          );

/// A made picture (or a video's first frame) shown in the thread at its own
/// shape, up to a comfortable size. Tapping it opens it in the vault.
///
/// [urls] are tried in order: the full picture, then its thumbnail. The
/// vault draws the thumbnail; the chat drew only the full picture, so a
/// full-size link that would not load (another host, a signed link that
/// had run out) showed "did not load" beside a vault showing it fine.
///
/// A picture that will not load from any of them says so, and why, rather
/// than showing drawn art in its place that could pass for what was made.
class MadePreview extends StatefulWidget {
  const MadePreview({
    required this.urls,
    required this.aspect,
    required this.video,
    required this.label,
    this.onTap,
    super.key,
  }) : assert(urls.length > 0);

  final List<String> urls;
  final double aspect;
  final bool video;
  final String label;
  final VoidCallback? onTap;

  /// The link tried first.
  String get url => urls.first;

  /// Why a picture did not load, in a few words a screenshot can carry.
  static String reasonOf(Object error, String url) {
    final String host = Uri.tryParse(url)?.host ?? '';
    final String from = url.startsWith('data:')
        ? 'inline data'
        : host.isEmpty
            ? 'a link with no host'
            : host;
    if (error is NetworkImageLoadException) {
      return 'HTTP ${error.statusCode} from $from';
    }
    return 'could not load from $from';
  }

  @override
  State<MadePreview> createState() => _MadePreviewState();
}

class _MadePreviewState extends State<MadePreview> {
  int _at = 0;
  final List<String> _reasons = <String>[];

  @override
  void didUpdateWidget(MadePreview old) {
    super.didUpdateWidget(old);
    // A link that arrives later (the vault row read in) is a fresh try.
    if (old.urls.join('\n') != widget.urls.join('\n')) {
      _at = 0;
      _reasons.clear();
    }
  }

  void _failed(Object error) {
    final String url = widget.urls[_at];
    final String reason = MadePreview.reasonOf(error, url);
    debugPrint('made picture: $url — $reason');
    // Moved on after this frame: the error arrives while building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _at >= widget.urls.length) return;
      setState(() {
        _reasons.add(reason);
        _at++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final bool gone = _at >= widget.urls.length;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
      child: AspectRatio(
        aspectRatio: widget.aspect.clamp(0.5, 2.0),
        child: Semantics(
          image: true,
          button: widget.onTap != null,
          label: widget.video
              ? 'Video: ${widget.label}'
              : 'Image: ${widget.label}',
          child: GestureDetector(
            onTap: widget.onTap,
            child: ClipRRect(
              borderRadius: Radii.lgAll,
              child: ColoredBox(
                color: c.surface,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (gone)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Space.x4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'The picture did not load. It is saved in '
                                'your vault.',
                                textAlign: TextAlign.center,
                                style: ShiftType.bodySm(c.textMuted),
                              ),
                              const SizedBox(height: Space.x1),
                              Text(
                                _reasons.toSet().join(' · '),
                                textAlign: TextAlign.center,
                                style: ShiftType.caption(c.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      KeyedSubtree(
                        key: ValueKey<String>(widget.urls[_at]),
                        child: networkPicture(
                          widget.urls[_at],
                          loadingBuilder: (BuildContext context, Widget child,
                                  ImageChunkEvent? progress) =>
                              progress == null
                                  ? child
                                  : Center(
                                      child: ShiftSpinner(color: c.textMuted),
                                    ),
                          errorBuilder: (BuildContext context, Object error,
                              StackTrace? _) {
                            _failed(error);
                            return Center(
                              child: ShiftSpinner(color: c.textMuted),
                            );
                          },
                        ),
                      ),
                    if (widget.video) const Center(child: PlayDisc(size: 56)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
