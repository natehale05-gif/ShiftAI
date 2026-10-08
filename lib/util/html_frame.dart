// A web page a model wrote, shown as the page itself. On the web it is a
// sandboxed <iframe>; elsewhere there is no browser to draw it with, so
// the card shows its code and says where to open it.
export 'html_frame_stub.dart'
    if (dart.library.js_interop) 'html_frame_web.dart';
