import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Whether this platform can draw a page here.
const bool canShowHtml = true;

/// The page in an <iframe>, sandboxed to scripts only: no same-origin, so
/// what a model wrote cannot read the app's storage (the session lives
/// there), and no top navigation, forms or pop-ups. Inline it ignores the
/// pointer, so the thread scrolls over it; full screen it is used.
Widget htmlFrame(String html, {required bool interactive}) =>
    HtmlElementView.fromTagName(
      key: ValueKey<Object>(Object.hash(html, interactive)),
      tagName: 'iframe',
      onElementCreated: (Object element) {
        final web.HTMLIFrameElement frame = element as web.HTMLIFrameElement;
        frame.sandbox.add('allow-scripts');
        frame.style
          ..border = '0'
          ..width = '100%'
          ..height = '100%'
          ..backgroundColor = 'white'
          ..pointerEvents = interactive ? 'auto' : 'none';
        frame.srcdoc = html.toJS;
      },
    );

/// Saves [html] as [fileName] through the browser's own download.
bool downloadHtml(String fileName, String html) {
  final web.Blob blob = web.Blob(
    <JSAny>[html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final String url = web.URL.createObjectURL(blob);
  final web.HTMLAnchorElement link =
      web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = fileName;
  link.click();
  web.URL.revokeObjectURL(url);
  return true;
}
