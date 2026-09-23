import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/app/modes.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/features/vault/vault_surface.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

void main() {
  List<String> titles(List<VaultItem> items) =>
      items.map((VaultItem v) => v.title).toList();

  test('every word has to match, in any order and any case', () {
    expect(titles(vaultMatches(Seed.ecoVault, 'DUSK ferry')),
        contains('Ferry wake at dusk'));
    expect(vaultMatches(Seed.ecoVault, 'ferry nonsense'), isEmpty);
  });

  test('the creator counts, not just the title', () {
    final List<VaultItem> byPriya = vaultMatches(Seed.ecoVault, 'priya');
    expect(byPriya, isNotEmpty);
    expect(byPriya.every((VaultItem v) => v.byName == 'Priya Balan'), isTrue);
  });

  test('an empty query is everything', () {
    expect(vaultMatches(Seed.vault, '   ').length, Seed.vault.length);
  });

  testWidgets(
      'searching the vault narrows the grid and says when nothing '
      'matches', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(412 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
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
    await tester.pumpAndSettle();
    expect(find.text('Cover art, warm pass'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'rooftop');
    await tester.pumpAndSettle();
    expect(find.text('Rooftop loop, take 3'), findsOneWidget);
    expect(find.text('Cover art, warm pass'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'no such piece');
    await tester.pumpAndSettle();
    expect(find.text('No results'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Cover art, warm pass'), findsOneWidget);
  });
}
