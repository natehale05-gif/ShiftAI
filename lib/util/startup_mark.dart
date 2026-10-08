// The moment the app first draws real content rather than its loading
// screen, as a `shift-ready` performance mark on the web: how start-up is
// timed from a browser. Nothing elsewhere.
export 'startup_mark_stub.dart'
    if (dart.library.js_interop) 'startup_mark_web.dart';
