import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/app/modes.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/state/app_state.dart';
import 'package:shift_ai/state/daily_rings.dart';
import 'package:shift_ai/util/haptics.dart';

void main() {
  test('a haptic with no platform behind it is a no-op, not a crash', () {
    // Plain unit tests load AppState with no binding at all; a ring closing
    // there must not throw.
    Haptics.selection();
    Haptics.light();
    Haptics.success();
  });

  testWidgets('choices tick, saves tap, and a closing ring lands firmer',
      (WidgetTester tester) async {
    final List<String> felt = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          felt.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppState state = await AppState.load(tokenStore: MemoryTokenStore());
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pumpAndSettle();
    final Finder close = find.byTooltip('Close');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first);
      await tester.pumpAndSettle();
    }

    // A segmented control changing: Agents to Jobs.
    state.setSurface(Surface.agents);
    await tester.pumpAndSettle();
    felt.clear();
    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    expect(felt, <String>['HapticFeedbackType.selectionClick']);

    // Tapping the segment already chosen is not a change.
    felt.clear();
    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    expect(felt, isEmpty);

    // Saving from EcoVault is a light tap.
    state.setSurface(Surface.vault);
    await tester.pumpAndSettle();
    await tester.tap(find.text('EcoVault'));
    await tester.pumpAndSettle();
    // EcoVault is a feed: the first post not yet saved may be further
    // down, built only once it is scrolled to.
    await tester.scrollUntilVisible(
      find.byTooltip('Save to your vault'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    felt.clear();
    await tester.tap(find.byTooltip('Save to your vault').first);
    await tester.pumpAndSettle();
    expect(felt, contains('HapticFeedbackType.lightImpact'));

    // A ring closing for the first time today is firmer, once. The
    // compete ring closes on opening the leaderboard.
    expect(state.rings.isClosed(RingKind.compete), isFalse);
    felt.clear();
    state.setSurface(Surface.earnings);
    await tester.pumpAndSettle();
    expect(felt, <String>['HapticFeedbackType.mediumImpact']);
    felt.clear();
    state.setSurface(Surface.suite);
    state.setSurface(Surface.earnings);
    await tester.pumpAndSettle();
    expect(felt, isEmpty);
  });
}
