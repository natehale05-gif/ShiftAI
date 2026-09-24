import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'share_outcome.dart';

/// The browser's own share sheet where it has one (phones, Safari), the
/// clipboard where it does not (most desktop browsers).
Future<ShareOutcome> shareText(
  String text, {
  String? subject,
  Rect? origin,
}) async {
  final web.ShareData data = web.ShareData(text: text, title: subject ?? '');
  bool can = false;
  try {
    can = web.window.navigator.canShare(data);
  } on Object {
    can = false;
  }
  if (can) {
    try {
      await web.window.navigator.share(data).toDart;
      return ShareOutcome.shared;
    } on Object {
      // Closing the sheet rejects the promise, as does a refusal.
      return ShareOutcome.dismissed;
    }
  }
  await Clipboard.setData(ClipboardData(text: text));
  return ShareOutcome.copied;
}
