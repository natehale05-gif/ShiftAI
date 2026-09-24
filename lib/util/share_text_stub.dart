import 'package:flutter/services.dart';

import 'share_outcome.dart';

/// Nowhere to share to: the text goes on the clipboard.
Future<ShareOutcome> shareText(
  String text, {
  String? subject,
  Rect? origin,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  return ShareOutcome.copied;
}
