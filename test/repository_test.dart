import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shift_ai/data/api/api_client.dart';
import 'package:shift_ai/data/api/http_repository.dart';
import 'package:shift_ai/data/repository.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/features/settings/connectors.dart';
import 'package:shift_ai/models/models.dart';

/// A stand-in server. Every test states exactly what the engine answers,
/// so what is being checked is the client's half of the contract.
class _FakeServer extends http.BaseClient {
  _FakeServer(this.handler);

  final http.Response Function(http.BaseRequest request) handler;
  final List<http.BaseRequest> seen = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    seen.add(request);
    final http.Response r = handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(r.body)),
      r.statusCode,
      headers: r.headers,
      request: request,
    );
  }
}

String _json(Object? body) => jsonEncode(body);

/// The smallest answer that satisfies a snapshot load.
http.Response _snapshotRoute(http.BaseRequest request) {
  final String path = request.url.path;
  return switch (path) {
    '/v1/me' => http.Response(
        _json(<String, dynamic>{
          'handle': 'shiftai',
          'name': 'SHIFT AI',
          'email': 'demo@shiftai.club',
        }),
        200,
      ),
    '/v1/standings' => http.Response(
        _json(<Map<String, dynamic>>[
          <String, dynamic>{
            'rank': 1,
            'name': 'Marisol Vega',
            'earnings': 11727.62,
            'movement': 0,
            'tier': 'gold',
          },
          <String, dynamic>{
            'rank': 2,
            'name': 'You',
            'earnings': 767.09,
            'movement': 1,
            'isYou': true,
          },
        ]),
        200,
      ),
    '/v1/trophies' => http.Response(
        _json(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'out_loud',
            'earnedOn': '2026-09-01T00:00:00.000Z',
            'progress': 1.0,
          },
        ]),
        200,
      ),
    '/v1/vault' => http.Response(
        _json(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'v1',
            'title': 'Rooftop loop, take 3',
            'kind': 'video',
            'prompt': 'Slow push in on a rooftop at blue hour.',
            'model': 'HeyGen · video v2',
            'createdAt': '2026-09-16T21:14:00Z',
            'credits': 14,
            'aspect': 0.5625,
          },
        ]),
        200,
      ),
    '/v1/notes' => http.Response(
        _json(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'n1',
            'title': 'From the server',
            'body': 'Hello',
            'editedAt': '2026-09-17T10:00:00.000Z',
          },
        ]),
        200,
      ),
    '/v1/agents/runs' => http.Response(
        _json(<String, dynamic>{
          'rows': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'r1',
              'title': 'Scan imports',
              'status': 'failed',
            },
          ],
        }),
        200,
      ),
    '/v1/agents/jobs' => http.Response(_json(<Map<String, dynamic>>[]), 200),
    '/v1/designs' => http.Response(
        _json(<Map<String, dynamic>>[
          <String, dynamic>{'id': 'd1', 'title': 'Palette', 'versions': 2},
        ]),
        200,
      ),
    '/v1/ecovault' => http.Response(
        _json(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'e-1',
            'title': 'Tide clock, slow dissolve',
            'kind': 'video',
            'prompt': 'A tide clock on a weathered wall.',
            'model': 'HeyGen · video v2',
            'createdAt': '2026-09-17T08:12:00Z',
            'credits': 18,
            'aspect': 1.777,
            'published': true,
            'byHandle': 'marisol',
            'byName': 'Marisol Vega',
            'saved': true,
          },
          <String, dynamic>{
            'id': 'e-2',
            'title': 'Salt flats, first light',
            'kind': 'image',
            'prompt': 'Salt flats at first light.',
            'model': 'Image · standard',
            'createdAt': '2026-09-16T06:40:00Z',
            'credits': 5,
            'aspect': 1.5,
            'published': true,
            'byHandle': 'tomas',
            'byName': 'Tomas Lindqvist',
          },
        ]),
        200,
      ),
    '/v1/connections' => http.Response(
        _json(<Map<String, dynamic>>[
          <String, dynamic>{'name': 'Gmail', 'live': true},
        ]),
        200,
      ),
    '/v1/week' => http.Response(
        _json(<String, dynamic>{'pool': 53497, 'payoutLine': 'FRIDAY'}),
        200,
      ),
    '/v1/avatars' => http.Response(
        _json(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'a1',
            'name': 'Everyday',
            'status': 'ready',
            'personal': true,
            'previewUrl': 'https://example.com/a1.png',
          },
        ]),
        200,
      ),
    // Not placed yet, same as a brand new account — see `League.fromJson`.
    '/v1/league' => http.Response(_json(<String, dynamic>{}), 200),
    _ => http.Response('{"message":"no route"}', 404),
  };
}

void main() {
  group('the HTTP repository speaks the documented contract', () {
    test('a snapshot comes back as models', () async {
      final _FakeServer server = _FakeServer(_snapshotRoute);
      final ShiftRepository repo = HttpRepository(
        ApiClient(baseUrl: 'https://api.example.com', client: server),
      );

      final ShiftSnapshot snap = await repo.load();
      expect(snap.creator.name, 'SHIFT AI');
      // Initials are derived when the server does not send them.
      expect(snap.creator.initials, 'SA');
      expect(snap.standings.length, 2);
      expect(snap.standings.last.isYou, isTrue);
      expect(snap.notes.single.title, 'From the server');
      expect(snap.agentRuns.single.status, RunStatus.failed);
      expect(snap.designs.single.versions, 2);
      // The catalogue is the client's, so every connector it knows about
      // comes back; the server only says which of them this account has
      // authorised. Anything it did not name reads as not connected.
      expect(snap.connectors.length, ConnectorCatalog.all.length);
      expect(
        snap.connectors.firstWhere((Connector c) => c.name == 'Gmail').live,
        isTrue,
      );
      expect(
        snap.connectors.where((Connector c) => c.live).length,
        1,
        reason: 'only what the server named is live',
      );
      expect(snap.weekPool, 53497);

      expect(snap.avatars.single.name, 'Everyday');
      expect(snap.avatars.single.status, AvatarStatus.ready);
      expect(snap.avatars.single.personal, isTrue);

      // EcoVault carries an author and the viewer's own heart. A row with
      // no author is the viewer's own work; the heart is per-viewer, so
      // it rides on the row rather than on the piece.
      expect(snap.ecoVault.length, 2);
      final VaultItem tide =
          snap.ecoVault.firstWhere((VaultItem v) => v.id == 'e-1');
      expect(tide.byName, 'Marisol Vega');
      expect(tide.mine, isFalse);
      expect(tide.saved, isTrue);
      expect(
        snap.ecoVault.firstWhere((VaultItem v) => v.id == 'e-2').saved,
        isFalse,
      );
      expect(snap.vault.first.mine, isTrue, reason: 'no author means yours');

      // The trophy catalogue stays local; the server only says which are
      // earned, so the artwork and tiers survive the round trip.
      expect(snap.trophies.length, 18);
      final Trophy first =
          snap.trophies.firstWhere((Trophy t) => t.id == 'out_loud');
      expect(first.earned, isTrue);
      expect(first.name, isNotEmpty);
    });

    test('the token goes out on every request', () async {
      final _FakeServer server = _FakeServer(_snapshotRoute);
      final ShiftRepository repo = HttpRepository(
        ApiClient(
          baseUrl: 'https://api.example.com/',
          client: server,
          tokenProvider: () async => 'abc123',
        ),
      );
      await repo.load();
      expect(server.seen, isNotEmpty);
      for (final http.BaseRequest r in server.seen) {
        expect(r.headers['Authorization'], 'Bearer abc123');
        // A trailing slash on the base URL must not double up.
        expect(r.url.toString(), isNot(contains('//v1')));
      }
    });

    test('status codes become something the UI can act on', () async {
      Future<ShiftApiException> failWith(int status) async {
        final ShiftRepository repo = HttpRepository(
          ApiClient(
            baseUrl: 'https://api.example.com',
            client: _FakeServer(
              (_) => http.Response('{"message":"nope"}', status),
            ),
          ),
        );
        try {
          await repo.load();
          fail('expected $status to throw');
        } on ShiftApiException catch (error) {
          return error;
        }
      }

      expect((await failWith(401)).kind, ShiftApiErrorKind.unauthorised);
      expect((await failWith(403)).kind, ShiftApiErrorKind.forbidden);
      expect((await failWith(404)).kind, ShiftApiErrorKind.notFound);
      expect((await failWith(422)).kind, ShiftApiErrorKind.badRequest);
      expect((await failWith(500)).kind, ShiftApiErrorKind.server);
      // The server's own words reach the person, not a status code.
      expect((await failWith(500)).message, 'nope');
      // Only the ones worth retrying say so.
      expect((await failWith(500)).retryable, isTrue);
      expect((await failWith(401)).retryable, isFalse);
    });

    test('a body that breaks the contract is caught here', () async {
      final ShiftRepository repo = HttpRepository(
        ApiClient(
          baseUrl: 'https://api.example.com',
          client: _FakeServer((http.BaseRequest r) => r.url.path == '/v1/me'
              ? http.Response('{"name":"No handle"}', 200)
              : _snapshotRoute(r)),
        ),
      );
      await expectLater(
        repo.load(),
        throwsA(
          isA<ShiftApiException>().having(
            (ShiftApiException e) => e.kind,
            'kind',
            ShiftApiErrorKind.malformed,
          ),
        ),
      );
    });

    test('a write sends the right verb and path', () async {
      final _FakeServer server = _FakeServer(
        (http.BaseRequest r) => http.Response(
          _json(<String, dynamic>{
            'id': 'n9',
            'title': 'Saved',
            'body': 'Body',
            'editedAt': '2026-09-17T10:00:00.000Z',
          }),
          200,
        ),
      );
      final ShiftRepository repo = HttpRepository(
        ApiClient(baseUrl: 'https://api.example.com', client: server),
      );

      final Note made = await repo.createNote(title: 'Saved', body: 'Body');
      expect(made.id, 'n9');
      expect(server.seen.single.method, 'POST');
      expect(server.seen.single.url.path, '/v1/notes');

      await repo.saveNote('n9', title: 'Saved', body: 'Body');
      expect(server.seen.last.method, 'PATCH');
      expect(server.seen.last.url.path, '/v1/notes/n9');
    });

    test('changing the handle patches /v1/me', () async {
      final _FakeServer server = _FakeServer(
        (http.BaseRequest r) => http.Response(
          _json(<String, dynamic>{
            'handle': 'shiftai2',
            'name': 'SHIFT AI',
            'email': 'demo@shiftai.club',
          }),
          200,
        ),
      );
      final ShiftRepository repo = HttpRepository(
        ApiClient(baseUrl: 'https://api.example.com', client: server),
      );

      final Creator next = await repo.updateHandle('shiftai2');
      expect(next.handle, 'shiftai2');
      expect(server.seen.single.method, 'PATCH');
      expect(server.seen.single.url.path, '/v1/me');
      expect(
        jsonDecode((server.seen.single as http.Request).body),
        <String, dynamic>{'handle': 'shiftai2'},
      );
    });

    test('creating an avatar uploads, then posts the upload id', () async {
      final _FakeServer server = _FakeServer(
        (http.BaseRequest r) => switch (r.url.path) {
          '/v1/uploads' => http.Response(_json(<String, String>{'id': 'u1'}), 200),
          '/v1/avatars' => http.Response(
              _json(<String, dynamic>{
                'id': 'a2',
                'name': 'Studio',
                'status': 'training',
              }),
              200,
            ),
          _ => http.Response('{"message":"no route"}', 404),
        },
      );
      final ShiftRepository repo = HttpRepository(
        ApiClient(baseUrl: 'https://api.example.com', client: server),
      );

      final String uploadId = await repo.upload(
        fileName: 'me.png',
        mimeType: 'image/png',
        bytes: <int>[1, 2, 3],
      );
      expect(uploadId, 'u1');

      final Avatar avatar =
          await repo.createAvatar(uploadId: uploadId, name: 'Studio');
      expect(avatar.status, AvatarStatus.training);
      final http.Request created = server.seen.last as http.Request;
      expect(created.method, 'POST');
      expect(created.url.path, '/v1/avatars');
      expect(
        jsonDecode(created.body),
        <String, dynamic>{'uploadId': 'u1', 'name': 'Studio'},
      );
    });

    test('making an avatar personal and deleting one hit the right routes',
        () async {
      final _FakeServer server = _FakeServer(
        (http.BaseRequest r) => http.Response(
          _json(<String, dynamic>{
            'id': 'a1',
            'name': 'Everyday',
            'status': 'ready',
            'personal': true,
          }),
          200,
        ),
      );
      final ShiftRepository repo = HttpRepository(
        ApiClient(baseUrl: 'https://api.example.com', client: server),
      );

      final Avatar made = await repo.makeAvatarPersonal('a1');
      expect(made.personal, isTrue);
      expect(server.seen.last.method, 'POST');
      expect(server.seen.last.url.path, '/v1/avatars/a1/personal');

      await repo.deleteAvatar('a1');
      expect(server.seen.last.method, 'DELETE');
      expect(server.seen.last.url.path, '/v1/avatars/a1');
    });
  });

  group('the seeded repository stands in for a server', () {
    test('it fails the way a server fails', () async {
      final SeedRepository repo = SeedRepository(replyDelay: Duration.zero);
      await expectLater(
        repo.deleteNote('nope').then((_) => repo.saveNote(
              'nope',
              title: 'x',
              body: 'y',
            )),
        throwsA(
          isA<ShiftApiException>().having(
            (ShiftApiException e) => e.status,
            'status',
            404,
          ),
        ),
      );
    });

    test('it answers a send with the canned reply', () async {
      final SeedRepository repo = SeedRepository(replyDelay: Duration.zero);
      final List<ChatMessage> answer = await repo.send('make me a promo');
      expect(answer, isNotEmpty);
      expect(answer.any((ChatMessage m) => m.attachment != null), isTrue);
    });

    test('changing the handle carries over to the next load', () async {
      final SeedRepository repo = SeedRepository(replyDelay: Duration.zero);
      final Creator before = (await repo.load()).creator;

      final Creator next = await repo.updateHandle('newhandle');
      expect(next.handle, 'newhandle');
      expect(next.name, before.name, reason: 'only the handle changed');
      expect((await repo.load()).creator.handle, 'newhandle');
    });

    test('only one avatar is personal at a time', () async {
      final SeedRepository repo = SeedRepository(replyDelay: Duration.zero);
      final List<Avatar> seeded = (await repo.load()).avatars;
      final Avatar wasPersonal = seeded.firstWhere((Avatar a) => a.personal);
      final Avatar toPromote = seeded.firstWhere((Avatar a) => !a.personal);

      final Avatar promoted = await repo.makeAvatarPersonal(toPromote.id);
      expect(promoted.personal, isTrue);

      final List<Avatar> after = (await repo.load()).avatars;
      expect(
        after.firstWhere((Avatar a) => a.id == wasPersonal.id).personal,
        isFalse,
      );
      expect(after.where((Avatar a) => a.personal).length, 1);
    });

    test('a created avatar starts training and can be deleted', () async {
      final SeedRepository repo = SeedRepository(replyDelay: Duration.zero);
      final int before = (await repo.load()).avatars.length;

      final Avatar created =
          await repo.createAvatar(uploadId: 'u1', name: 'New face');
      expect(created.status, AvatarStatus.training);
      expect((await repo.load()).avatars.length, before + 1);

      await repo.deleteAvatar(created.id);
      expect((await repo.load()).avatars.length, before);
    });
  });
}
