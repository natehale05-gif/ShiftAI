import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/app/modes.dart';
import 'package:shift_ai/data/repository.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/state/app_state.dart';

/// A repository that takes reads and refuses every write, which is what a
/// server does when the token has expired or the row has moved on.
class _RefusingRepository extends SeedRepository {
  _RefusingRepository() : super(replyDelay: Duration.zero);

  static Never _no() => throw const ShiftApiException(
        ShiftApiErrorKind.forbidden,
        'Not yours to change.',
        status: 403,
      );

  @override
  Future<VaultItem> saveVaultItem(String id) async => _no();

  @override
  Future<VaultItem> unsaveVaultItem(String id) async => _no();

  @override
  Future<VaultItem> renameVaultItem(String id, String title) async => _no();

  @override
  Future<VaultItem> publishVaultItem(String id) async => _no();

  @override
  Future<void> deleteVaultItem(String id) async => _no();

  @override
  Future<void> deleteNote(String id) async => _no();

  @override
  Future<Note> saveNote(
    String id, {
    required String title,
    required String body,
  }) async =>
      _no();

  @override
  Future<DesignDoc> duplicateDesign(String id) async => _no();

  @override
  Future<void> deleteDesign(String id) async => _no();

  @override
  Future<AgentRun> rerunRun(String id) async => _no();

  @override
  Future<AgentRun> startRun(String prompt, {required String scope}) async =>
      _no();
}

Future<AppState> _state({ShiftRepository? repo}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppState.load(
    repository: repo ?? SeedRepository(replyDelay: Duration.zero),
    tokenStore: MemoryTokenStore(),
  );
}

void main() {
  group('a write the engine refuses is undone and reported', () {
    test('every mutation answers false and puts the screen back', () async {
      final AppState state = await _state(repo: _RefusingRepository());

      final List<VaultItem> vaultBefore = List<VaultItem>.of(state.vault);
      final String id = state.vault.first.id;

      expect(await state.publishVaultItem(id), isFalse);
      expect(state.vault, equals(vaultBefore));
      expect(state.lastError, isNotNull);
      expect(state.lastError!.message, 'Not yours to change.');

      expect(await state.renameVaultItem(id, 'Something else'), isFalse);
      expect(state.vault.first.title, vaultBefore.first.title);

      expect(await state.deleteVaultItem(id), isFalse);
      expect(state.vault.length, vaultBefore.length);

      final List<DesignDoc> designsBefore = List<DesignDoc>.of(state.designs);
      expect(await state.duplicateDesign(state.designs.first.id), isFalse);
      expect(state.designs.length, designsBefore.length);
      expect(await state.deleteDesign(state.designs.first.id), isFalse);
      expect(state.designs.length, designsBefore.length);

      final int notesBefore = state.notes.length;
      expect(await state.deleteNote(state.notes.first.id), isFalse);
      expect(state.notes.length, notesBefore);

      final Note note = state.notes.first;
      expect(
        await state.saveNote(note.id, title: 'New', body: 'New'),
        isFalse,
      );
      expect(state.notes.first.title, note.title);
    });

    test('a refused delete keeps the item selected', () async {
      final AppState state = await _state(repo: _RefusingRepository());
      final String id = state.vault.first.id;
      state.selectVaultItem(id);

      expect(await state.deleteVaultItem(id), isFalse);
      expect(state.selectedVaultId, id);
      expect(state.selectedVaultItem, isNotNull);
    });

    test('a write that lands reports true and clears the error', () async {
      final AppState state = await _state();
      final String id = state.vault.first.id;

      expect(await state.publishVaultItem(id), isTrue);
      expect(state.vault.first.published, isTrue);
      expect(state.lastError, isNull);
    });
  });

  group("the day's three rings close on the actions they track", () {
    test('publishing closes the publish ring', () async {
      final AppState state = await _state();
      expect(state.rings.publish, isFalse);
      expect(await state.publishVaultItem(state.vault.first.id), isTrue);
      expect(state.rings.publish, isTrue);
    });

    test('a refused publish leaves the ring open', () async {
      final AppState state = await _state(repo: _RefusingRepository());
      expect(await state.publishVaultItem(state.vault.first.id), isFalse);
      expect(state.rings.publish, isFalse);
    });

    test('hearting someone else\'s work closes the publish ring too',
        () async {
      final AppState state = await _state();
      final VaultItem theirs = state.ecoVault
          .firstWhere((VaultItem v) => !v.mine && !v.saved);
      expect(state.rings.publish, isFalse);
      expect(await state.toggleSaved(theirs.id), isTrue);
      expect(state.rings.publish, isTrue);
    });

    test('taking a heart back does not reopen the ring', () async {
      final AppState state = await _state();
      final VaultItem theirs = state.ecoVault
          .firstWhere((VaultItem v) => !v.mine && !v.saved);
      await state.toggleSaved(theirs.id);
      expect(state.rings.publish, isTrue);
      expect(await state.toggleSaved(theirs.id), isTrue);
      expect(state.rings.publish, isTrue);
    });

    test('opening the leaderboard closes the compete ring', () async {
      final AppState state = await _state();
      expect(state.rings.compete, isFalse);
      state.setSurface(Surface.earnings);
      expect(state.rings.compete, isTrue);
    });
  });

  group('the Agents scope is real, not decoration', () {
    test('picking a scope moves the lists with it', () async {
      final AppState state = await _state();
      expect(state.agentScope, Seed.agentScope);
      expect(state.visibleRuns, isNotEmpty);

      final String other = Seed.agentScopes[1];
      state.setScope(other);

      expect(state.agentScope, other);
      // Nothing has run there yet, so the list is honestly empty rather
      // than showing another repository's work.
      expect(state.visibleRuns, isEmpty);

      state.setScope(Seed.agentScope);
      expect(state.visibleRuns, isNotEmpty);
    });

    test('the composer puts a real row in the scope showing', () async {
      final AppState state = await _state();
      final String other = Seed.agentScopes[2];
      state.setScope(other);

      expect(await state.startAgentWork('Tidy the brand tokens'), isTrue);

      expect(state.visibleRuns.length, 1);
      expect(state.visibleRuns.first.title, 'Tidy the brand tokens');
      expect(state.visibleRuns.first.status, RunStatus.working);
      expect(state.visibleRuns.first.scope, other);

      // And it stays on that scope rather than leaking into the default.
      state.setScope(Seed.agentScope);
      expect(
        state.visibleRuns
            .any((AgentRun r) => r.title == 'Tidy the brand tokens'),
        isFalse,
      );
    });

    test('jobs go to the job scope, not the repo scope', () async {
      final AppState state = await _state();
      state.showJobs(true);
      state.setScope(Seed.jobScopes[1]);

      expect(await state.startAgentWork('Export last quarter'), isTrue);
      expect(state.visibleJobs.single.title, 'Export last quarter');
      // Picking a job scope leaves the agent scope alone.
      expect(state.agentScope, Seed.agentScope);
    });

    test('an empty ask starts nothing', () async {
      final AppState state = await _state();
      final int before = state.agentRuns.length;
      expect(await state.startAgentWork('   '), isFalse);
      expect(state.agentRuns.length, before);
    });

    test('re-run puts the row back to working', () async {
      final AppState state = await _state();
      final AgentRun failed = state.agentRuns
          .firstWhere((AgentRun r) => r.status == RunStatus.failed);

      expect(await state.rerunAgent(failed.id), isTrue);

      final AgentRun after =
          state.agentRuns.firstWhere((AgentRun r) => r.id == failed.id);
      expect(after.status, RunStatus.working);
    });

    test('a refused re-run leaves the row as it was', () async {
      final AppState state = await _state(repo: _RefusingRepository());
      final AgentRun failed = state.agentRuns
          .firstWhere((AgentRun r) => r.status == RunStatus.failed);

      expect(await state.rerunAgent(failed.id), isFalse);
      expect(
        state.agentRuns.firstWhere((AgentRun r) => r.id == failed.id).status,
        RunStatus.failed,
      );
    });

    test('the chosen scope survives a reload', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppState first = await AppState.load(
          repository: SeedRepository(replyDelay: Duration.zero),
          tokenStore: MemoryTokenStore());
      first.setScope(Seed.agentScopes[1]);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final AppState second = await AppState.load(
          repository: SeedRepository(replyDelay: Duration.zero),
          tokenStore: MemoryTokenStore());
      expect(second.agentScope, Seed.agentScopes[1]);
    });
  });

  group('hearting a piece in EcoVault', () {
    test('puts it in your own vault, and taking the heart off removes it',
        () async {
      final AppState state = await _state();
      final VaultItem theirs =
          state.ecoVault.firstWhere((VaultItem v) => !v.mine && !v.saved);

      final int madeBefore = state.vault.length;
      state.setVaultScope(VaultScope.mine);
      expect(
        state.visibleVault.any((VaultItem v) => v.id == theirs.id),
        isFalse,
      );

      expect(await state.toggleSaved(theirs.id), isTrue);

      expect(
          state.savedFromEco.any((VaultItem v) => v.id == theirs.id), isTrue);
      expect(
        state.visibleVault.any((VaultItem v) => v.id == theirs.id),
        isTrue,
        reason: 'a hearted piece belongs in the personal vault',
      );
      // Saving is a bookmark, not a copy: it does not become your work.
      expect(state.vault.length, madeBefore);

      expect(await state.toggleSaved(theirs.id), isTrue);
      expect(
        state.visibleVault.any((VaultItem v) => v.id == theirs.id),
        isFalse,
      );
    });

    test('a saved piece keeps its author and is never yours', () async {
      final AppState state = await _state();
      final VaultItem theirs =
          state.ecoVault.firstWhere((VaultItem v) => !v.mine && !v.saved);
      await state.toggleSaved(theirs.id);

      final VaultItem inMine =
          state.myVault.firstWhere((VaultItem v) => v.id == theirs.id);
      expect(inMine.mine, isFalse);
      expect(inMine.byName, theirs.byName);
    });

    test('your own published work is in EcoVault without being "saved"',
        () async {
      final AppState state = await _state();
      final VaultItem published =
          state.ecoVault.firstWhere((VaultItem v) => v.mine);

      expect(published.byHandle, isNull);
      expect(
        state.savedFromEco.any((VaultItem v) => v.id == published.id),
        isFalse,
        reason: 'your own piece is in your vault because you made it',
      );
      // And it is not listed twice in My Vault.
      expect(
        state.myVault.where((VaultItem v) => v.id == published.id).length,
        1,
      );
    });

    test('a refused heart is rolled back', () async {
      final AppState state = await _state(repo: _RefusingRepository());
      final VaultItem theirs =
          state.ecoVault.firstWhere((VaultItem v) => !v.mine && !v.saved);

      expect(await state.toggleSaved(theirs.id), isFalse);
      expect(
        state.savedFromEco.any((VaultItem v) => v.id == theirs.id),
        isFalse,
      );
      expect(state.lastError, isNotNull);
    });

    test('the detail panel finds a piece in either list', () async {
      final AppState state = await _state();
      final VaultItem theirs =
          state.ecoVault.firstWhere((VaultItem v) => !v.mine);

      state.selectVaultItem(theirs.id);
      expect(state.selectedVaultItem?.id, theirs.id);

      state.selectVaultItem(state.vault.first.id);
      expect(state.selectedVaultItem?.id, state.vault.first.id);
    });
  });

  group("Vault's Re-run hands the prompt back", () {
    test('it lands in the composer draft and moves to Suite', () async {
      final AppState state = await _state();
      final VaultItem item = state.vault.first;
      state.selectVaultItem(item.id);

      state.reusePrompt(item.prompt);

      expect(state.mode, ShiftMode.suite);
      expect(state.surface, Surface.suite);
      expect(state.selectedVaultId, isNull);
      expect(state.takeComposerDraft(), item.prompt);
      // Taken once, so returning to Suite later does not re-fill the bar.
      expect(state.takeComposerDraft(), isNull);
    });

    testWidgets('the Suite bar is holding it when it builds',
        (WidgetTester tester) async {
      final AppState state = await _state();
      final VaultItem item = state.vault.first;

      state.reusePrompt(item.prompt);
      await tester.pumpWidget(ShiftApp(state: state));
      await tester.pumpAndSettle();

      expect(find.text(item.prompt), findsOneWidget);
    });
  });

  group('the sign-in gate checks the form', () {
    testWidgets('an empty form does not sign you in',
        (WidgetTester tester) async {
      final AppState state = await _state();
      state.signOut();
      await tester.pumpWidget(ShiftApp(state: state));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();

      expect(state.signedIn, isFalse);
      expect(
        find.text('Enter the email your membership is under.'),
        findsOneWidget,
      );
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('a filled form does', (WidgetTester tester) async {
      final AppState state = await _state();
      state.signOut();
      await tester.pumpWidget(ShiftApp(state: state));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'nate@example.com');
      await tester.enterText(find.byType(TextField).last, 'a-password');
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();

      expect(state.signedIn, isTrue);
    });
  });

  testWidgets('a trophy opens what its tile has to clip',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final AppState state = await _state();
    state.setSurface(Surface.trophies);
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pumpAndSettle();

    final Trophy trophy = state.trophies.first;
    await tester.tap(find.text(trophy.name).first);
    await tester.pumpAndSettle();

    expect(find.text('CLOSE'), findsOneWidget);
    expect(find.text(trophy.requirement), findsWidgets);

    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();
    expect(find.text('CLOSE'), findsNothing);
  });
}
