import 'package:flutter/widgets.dart';

/// Whether this platform can draw a page here.
const bool canShowHtml = false;

/// The page, drawn. Never built where [canShowHtml] is false.
Widget htmlFrame(String html, {required bool interactive}) =>
    const SizedBox.shrink();

/// Saves [html] as [fileName]. False where there is nothing to save with.
bool downloadHtml(String fileName, String html) => false;
