import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/features/widgets/widget_sync.dart';
import 'package:shift_ai/state/app_state.dart';

/// WidgetSync talks to a MethodChannel with no Dart-side fake to swap in
/// (the real implementation lives in platform code this test cannot
/// reach), so what is checked here is the one thing that matters most:
/// that the seeded demo's fake "You" row never reaches a call that would
/// end up pinned, looking real, on somebody's home screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('home_widget');
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      if (call.method == 'saveWidgetData') return true;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 200));

  Object? dataFor(String id) {
    for (final MethodCall call in calls.reversed) {
      if (call.method != 'saveWidgetData') continue;
      final Map<dynamic, dynamic> args = call.arguments as Map<dynamic, dynamic>;
      if (args['id'] == id) return args['data'];
    }
    return null;
  }

  test('the seeded demo writes nothing but clears', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppState state = await AppState.load(tokenStore: MemoryTokenStore());
    expect(state.seededDemo, isTrue);
    // The seed's "You" row is real data as far as AppState is concerned —
    // this is the exact case a naive `state.you == null` check would miss.
    expect(state.you, isNotNull);

    // AppState.load fires its own WidgetSync call and does not await it;
    // let that finish before clearing calls, or it keeps writing after
    // this test's own call below and the two interleave.
    await settle();
    calls.clear();
    await WidgetSync.push(state);

    expect(calls.where((c) => c.method == 'saveWidgetData'), isNotEmpty);
    expect(dataFor('you_rank'), isNull);
    expect(dataFor('podium_1_name'), isNull);
  });

  test('a real board writes real numbers', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppState state =
        await AppState.load(tokenStore: MemoryTokenStore());
    // Force the branch WidgetSync gates on, independent of how this
    // fixture happens to be signed in.
    state.seededDemo = false;
    await settle();
    calls.clear();

    await WidgetSync.push(state);

    expect(dataFor('you_rank'), state.you?.rank.toString());
    expect(dataFor('podium_1_name'), state.podium.first.name);

    // WidgetCenter.reloadTimelines(ofKind:) on iOS reloads exactly the
    // kind it is given — a shared bundle name here would reload nothing
    // real. Each updateWidget call has to name that widget's own kind.
    final Iterable<MethodCall> refreshes =
        calls.where((MethodCall c) => c.method == 'updateWidget');
    final Iterable<String?> iosNames = refreshes
        .map((MethodCall c) => (c.arguments as Map)['ios'] as String?);
    expect(iosNames.toSet(), <String>{'RankWidget', 'PodiumWidget', 'RivalsWidget'});
  });
}
