import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Off the web there is no meta tag to keep in step — iOS and Android draw
/// their own bars from the app's theme through the engine.
void applyBrowserChrome(Color background, {required String theme}) {}

/// Off the web the engine reports the system insets itself, through
/// MediaQuery, so there is nothing to add.
final ValueListenable<double> browserBottomInset = ValueNotifier<double>(0);

void watchBrowserInsets() {}
