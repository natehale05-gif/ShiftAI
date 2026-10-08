import 'package:web/web.dart' as web;

bool _marked = false;

/// Marks `shift-ready` on the page's performance timeline, once.
void markStartupReady() {
  if (_marked) return;
  _marked = true;
  web.window.performance.mark('shift-ready');
}
