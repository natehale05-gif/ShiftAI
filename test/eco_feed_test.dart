import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/app/modes.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/features/vault/eco_feed.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';
import 'package:shift_ai/util/format.dart';

Future<AppState> _openEcoVault(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppState state = await AppState.load(tokenStore: MemoryTokenStore());
  await tester.pumpWidget(ShiftApp(state: state));
  await tester.pumpAndSettle();
  final Finder close = find.byTooltip('Close');
  if (close.evaluate().isNotEmpty) {
    await tester.tap(close.first);
    await tester.pumpAndSettle();
  }
  state.setSurface(Surface.vault);
  state.setVaultScope(VaultScope.eco);
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('EcoVault is a feed of posts; your own vault stays a grid',
      (WidgetTester tester) async {
    final AppState state = await _openEcoVault(tester);
    final VaultItem first = state.ecoVault.first;

    expect(find.byType(FeedPost), findsWidgets);
    // Who made it, above the piece, and the caption below it.
    expect(find.text(first.byHandle!), findsWidgets);
    expect(find.text(first.model), findsWidgets);
    expect(
        find.textContaining(first.title, findRichText: true), findsOneWidget);
    expect(find.text('${Fmt.grouped(first.hearts!)} hearts'), findsOneWidget);

    state.setVaultScope(VaultScope.mine);
    await tester.pumpAndSettle();
    expect(find.byType(FeedPost), findsNothing);
  });

  testWidgets('double tap hearts a post, and a second leaves it hearted',
      (WidgetTester tester) async {
    final AppState state = await _openEcoVault(tester);
    // The first post in the demo is already saved; the second is not.
    final VaultItem post = state.ecoVault[1];
    expect(post.saved, isFalse);
    final int before = post.hearts!;

    final Finder media = find.descendant(
      of: find.byKey(ValueKey<String>('post-${post.id}')),
      matching: find.byType(AspectRatio),
    );
    await tester.scrollUntilVisible(media, 300,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();

    Future<void> doubleTap() async {
      await tester.tap(media.first);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(media.first);
      await tester.pumpAndSettle();
    }

    await doubleTap();
    VaultItem now = state.ecoVault.firstWhere((VaultItem v) => v.id == post.id);
    expect(now.saved, isTrue);
    expect(now.hearts, before + 1, reason: 'the count moves with the heart');

    await doubleTap();
    now = state.ecoVault.firstWhere((VaultItem v) => v.id == post.id);
    expect(now.saved, isTrue, reason: 'double tap only ever adds a heart');
    expect(now.hearts, before + 1);
  });

  testWidgets('no count from the engine means no hearts line at all',
      (WidgetTester tester) async {
    final AppState state = await _openEcoVault(tester);
    final VaultItem first = state.ecoVault.first;
    state.ecoVault = <VaultItem>[
      VaultItem.fromJson(<String, dynamic>{
        ...first.toJson(),
        'hearts': null,
      }),
      ...state.ecoVault.skip(1),
    ];
    state.setVaultScope(VaultScope.mine);
    state.setVaultScope(VaultScope.eco);
    await tester.pumpAndSettle();
    expect(find.text('${Fmt.grouped(first.hearts!)} hearts'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(ValueKey<String>('post-${first.id}')),
        matching: find.textContaining('heart'),
      ),
      findsNothing,
    );
  });

  test('a tall clip is framed at 4:5 and a panorama at 1.91:1', () {
    VaultItem shaped(double aspect) => VaultItem.fromJson(<String, dynamic>{
          ...Seed.ecoVault.first.toJson(),
          'aspect': aspect,
        });
    expect(FeedPost.frameOf(shaped(9 / 16)), 0.8);
    expect(FeedPost.frameOf(shaped(3)), 1.91);
    expect(FeedPost.frameOf(shaped(1)), 1);
  });

  test('how long ago, the way a feed says it', () {
    final DateTime now = DateTime(2026, 9, 24, 12);
    expect(Fmt.ago(now, now: now), 'Just now');
    expect(Fmt.ago(DateTime(2026, 9, 24, 11, 59), now: now), '1 minute ago');
    expect(Fmt.ago(DateTime(2026, 9, 24, 9), now: now), '3 hours ago');
    expect(Fmt.ago(DateTime(2026, 9, 22, 12), now: now), '2 days ago');
    expect(Fmt.ago(DateTime(2026, 9, 1), now: now), '1 Sep 2026');
  });
}
