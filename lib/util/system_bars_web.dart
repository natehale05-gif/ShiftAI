import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

/// Repoints `<meta name="theme-color">` at the theme that is actually
/// showing.
///
/// The tag ships hard-coded to the theme a new account opens on, which is
/// right for the first paint and wrong from the moment anybody switches:
/// Chrome for Android paints the status bar — and, for an installed app,
/// the navigation bar — from this tag and nothing else. A light theme was
/// leaving both of them on the dark theme's near-black, which is the black
/// band above and below the app on a Pixel.
///
/// The document's own background goes with it, on `<body>` as well as
/// `<html>`. Both are hard-coded to the dark theme by the hosted shell's
/// stylesheet, and both matter: Chrome paints the strip behind the gesture
/// pill from the document background, not from the tag above, which is why
/// fixing only the tag left a black bar along the bottom of a cream theme.
/// The overscroll gutter behind a rubber-banded scroll comes from the same
/// place, so it stops flashing the wrong colour too.
///
/// Neither reaches the navigation bar of an *installed* app. Chrome paints
/// that from the manifest's colours, which it reads when it builds the
/// app and again only when it checks the installed app for updates, which
/// is at most about once a day. After a
/// delete-and-reinstall on a Pixel the bar was still `#0A0A0F`, the one
/// manifest's colour, under a light theme. So there is a manifest per
/// theme (`web/manifest-<theme>.json`) and the page links the one that is
/// showing. Chrome's next update check finds new colours and rebuilds the
/// installed app with them. That is not instant, but it is the only
/// signal the navigation bar listens to.
void applyBrowserChrome(Color background, {required String theme}) {
  final String colour = _css(background);

  web.HTMLMetaElement? tag = web.document
      .querySelector('meta[name="theme-color"]') as web.HTMLMetaElement?;
  if (tag == null) {
    // A page built without the tag (a plain `flutter build web`) still
    // gets one, rather than this being a no-op on half the builds.
    tag = web.document.createElement('meta') as web.HTMLMetaElement;
    tag.name = 'theme-color';
    web.document.head?.appendChild(tag);
  }
  if (tag.content != colour) tag.content = colour;

  (web.document.documentElement as web.HTMLElement?)?.style.backgroundColor =
      colour;
  web.document.body?.style.backgroundColor = colour;

  final String manifest = 'manifest-$theme.json';
  final web.HTMLLinkElement? link = web.document
      .querySelector('link[rel="manifest"]') as web.HTMLLinkElement?;
  // Compared on the attribute, not `href`, which comes back absolute.
  if (link != null && link.getAttribute('href') != manifest) {
    link.setAttribute('href', manifest);
  }
}

String _css(Color colour) {
  final int argb = colour.toARGB32();
  final String hex =
      (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  return '#$hex';
}
