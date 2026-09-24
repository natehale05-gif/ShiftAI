import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'share_outcome.dart';

/// The system share sheet. [origin] is where the sheet points from; an
/// iPad requires one, and without it the share throws there.
Future<ShareOutcome> shareText(
  String text, {
  String? subject,
  Rect? origin,
}) async {
  try {
    final ShareResult result = await SharePlus.instance.share(
      ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
    );
    return switch (result.status) {
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      _ => ShareOutcome.shared,
    };
  } on Object {
    // A desktop, or a platform with no sheet: the clipboard still works.
    await Clipboard.setData(ClipboardData(text: text));
    return ShareOutcome.copied;
  }
}
