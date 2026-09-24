// Sharing text through the system's own share sheet. On iOS and Android
// that is share_plus; on the web it is the browser's Web Share, where
// there is one, and the clipboard where there is not. share_plus's own web
// fallback opens a mailto: link, which on a desktop is an empty email.
export 'share_outcome.dart';
export 'share_text_stub.dart'
    if (dart.library.js_interop) 'share_text_web.dart'
    if (dart.library.io) 'share_text_io.dart';
