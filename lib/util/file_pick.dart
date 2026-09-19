// Picking files off the device. The web build opens the browser's own
// dialog; iOS, Android and desktop go through the platform picker. The
// stub is what a test binds to, and answers "nothing was picked".
export 'file_pick_stub.dart'
    if (dart.library.js_interop) 'file_pick_web.dart'
    if (dart.library.io) 'file_pick_io.dart';
