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
/// The `<html>` background goes with it, so the overscroll gutter behind a
/// rubber-banded scroll is the same colour rather than a flash of white.
void applyBrowserChrome(Color background) {
  final String colour = _css(background);

  web.HTMLMetaElement? tag =
      web.document.querySelector('meta[name="theme-color"]')
          as web.HTMLMetaElement?;
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
}

String _css(Color colour) {
  final int argb = colour.toARGB32();
  final String hex =
      (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  return '#$hex';
}
