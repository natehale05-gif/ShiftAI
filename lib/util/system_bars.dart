// Keeping the chrome *around* the app — Android's status and navigation
// bars on an installed web app — on the same colour as the theme showing.
// Off the web the engine already does this, so the stub does nothing.
export 'system_bars_stub.dart'
    if (dart.library.js_interop) 'system_bars_web.dart';
