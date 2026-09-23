import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/app/modes.dart';
import 'package:shift_ai/data/api/api_client.dart';
import 'package:shift_ai/data/api/decode.dart';
import 'package:shift_ai/data/api/http_repository.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/repository.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

/// Shaped as Rex's notes describe `GET /v1/boards`.
Map<String, dynamic> _boardsBody() => <String, dynamic>{
      'data': <String, dynamic>{
        'compete': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'u2',
            'display_name': 'Marty',
            'avatar_url': '',
            'current_tier': 2,
            'tier_name': 'Silver',
            'is_me': false,
            'rank': 2,
            'combined_cents': '98765',
          },
          <String, dynamic>{
            'id': 'u1',
            'display_name': 'Rex Wilson',
            'avatar_url': null,
            'current_tier': 3,
            'tier_name': 'Gold',
            'is_me': false,
            'rank': 1,
            'combined_cents': 123456,
          },
          <String, dynamic>{
            'id': 'u3',
            'display_name': 'Nate',
            'avatar_url': null,
            'current_tier': 1,
            'tier_name': 'Founding member',
            'is_me': true,
            'rank': 3,
            'combined_cents': 4200,
          },
        ],
        'lifetime': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'u1',
            'display_name': 'Rex Wilson',
            'is_me': false,
            'rank': 1,
            'earned_cents': '1000000',
          },
        ],
        'crowd': <Map<String, dynamic>>[],
        'my_pool_standings': <String, dynamic>{},
      },
    };

class _Server extends http.BaseClient {
  _Server(this.boards);
  final Map<String, dynamic>? boards;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final String path = request.url.path;
    final (int, Object?) answer = switch (path) {
      '/v1/me' => (
          200,
          <String, dynamic>{
            'handle': 'nate',
            'name': 'Nate',
            'email': 'n@example.com',
          }
        ),
      '/v1/boards' when boards != null => (200, boards),
      '/v1/boards' => (404, <String, dynamic>{'message': 'no route'}),
      '/v1/week' || '/v1/league' => (200, <String, dynamic>{}),
      _ => (200, <Object?>[]),
    };
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(answer.$2))),
      answer.$1,
      request: request,
    );
  }
}

void main() {
  test('cents come as numbers or strings, and become dollars', () {
    expect(Decode.cents(123456), 123456);
    expect(Decode.cents('98765'), 98765);
    expect(Decode.cents('12.0'), 12);
    expect(Decode.cents(null), 0);
    expect(Decode.cents('not money'), 0);
  });

  test('each board is ranked, with you marked and the Suite\'s labels', () {
    final SuiteBoards boards = Decode.boards(_boardsBody());
    // Empty boards are left out, and the Suite's order is kept.
    expect(boards.available, <SuiteBoard>[
      SuiteBoard.compete,
      SuiteBoard.lifetime,
    ]);
    final List<StandingRow> compete = boards.rows[SuiteBoard.compete]!;
    expect(compete.map((StandingRow r) => r.rank), <int>[1, 2, 3]);
    expect(compete.first.name, 'Rex Wilson');
    expect(compete.first.earnings, 1234.56);
    expect(compete[1].earnings, 987.65);
    expect(compete.first.tier, TrophyTier.gold);
    // A tier name that is not one of the four is left without a colour.
    expect(compete.last.tier, isNull);
    expect(compete.last.isYou, isTrue);
    expect(compete.every((StandingRow r) => !r.movementKnown), isTrue);
    // An empty avatar URL is no avatar, not a broken image.
    expect(compete[1].avatarUrl, isNull);
    expect(boards.rows[SuiteBoard.lifetime]!.single.earnings, 10000);
    expect(SuiteBoard.compete.label, 'CompetePay');
    expect(SuiteBoard.connectWeek.label, 'CoachPay this week');
  });

  test('an engine without /v1/boards still loads, with no boards', () async {
    final ShiftSnapshot without = await HttpRepository(
      ApiClient(baseUrl: 'https://api.example.com', client: _Server(null)),
    ).load();
    expect(without.boards, isNull);

    final ShiftSnapshot with_ = await HttpRepository(
      ApiClient(
        baseUrl: 'https://api.example.com',
        client: _Server(_boardsBody()),
      ),
    ).load();
    expect(with_.boards!.available, contains(SuiteBoard.compete));
  });

  testWidgets('the Global tab shows every Suite board, picked by chip',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(412 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SuiteBoards boards = Decode.boards(_boardsBody());
    final ShiftSnapshot seeded = await SeedRepository().load();
    final AppState state = await AppState.load(
      tokenStore: MemoryTokenStore(),
      repository: _WithBoards(seeded, boards),
    );
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pumpAndSettle();
    final Finder close = find.byTooltip('Close');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first);
      await tester.pumpAndSettle();
    }
    state.setSurface(Surface.earnings);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Global'));
    await tester.pumpAndSettle();

    expect(find.text('CompetePay'), findsOneWidget);
    expect(find.text('Lifetime earnings'), findsOneWidget);
    expect(find.text('Window earnings'), findsNothing);
    expect(find.text('Rex Wilson'), findsWidgets);
    expect(
      find.bySemanticsLabel(RegExp(r'You are 3rd, \$42\.00 CompetePay')),
      findsOneWidget,
    );

    // Nate is not on the lifetime board: it still draws, with no card for
    // him and no "no board yet".
    await tester.tap(find.text('Lifetime earnings'));
    await tester.pumpAndSettle();
    expect(find.text('No board yet'), findsNothing);
    expect(find.textContaining(r'$10,000'), findsWidgets);
  });
}

/// The seeded catalogue with the Suite's boards laid over it.
class _WithBoards extends SeedRepository {
  _WithBoards(this.base, this.boards);
  final ShiftSnapshot base;
  final SuiteBoards boards;

  @override
  Future<ShiftSnapshot> load() async => ShiftSnapshot(
        creator: base.creator,
        standings: base.standings,
        trophies: base.trophies,
        vault: base.vault,
        ecoVault: base.ecoVault,
        notes: base.notes,
        agentRuns: base.agentRuns,
        jobs: base.jobs,
        designs: base.designs,
        connectors: base.connectors,
        weekPool: base.weekPool,
        payoutLine: base.payoutLine,
        avatars: base.avatars,
        league: base.league,
        boards: boards,
      );
}
