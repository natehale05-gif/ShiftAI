import '../../models/models.dart';
import 'dart:async';

import '../../util/prompt.dart';
import '../repository.dart';
import '../seed_repository.dart';
import 'api_client.dart';
import 'decode.dart';

/// The repository that talks to a real engine.
///
/// Every path is named here, once. `docs/API.md` is the contract this file
/// implements — if the two ever disagree, this file is what runs, so change
/// both together.
class HttpRepository implements ShiftRepository {
  HttpRepository(this._api);

  final ApiClient _api;

  // Paths -----------------------------------------------------------------
  static const String _me = '/v1/me';
  static const String _standings = '/v1/standings';
  static const String _trophies = '/v1/trophies';
  static const String _vault = '/v1/vault';
  static const String _eco = '/v1/ecovault';
  static const String _notes = '/v1/notes';
  static const String _agents = '/v1/agents/runs';
  static const String _jobs = '/v1/agents/jobs';
  static const String _designs = '/v1/designs';
  static const String _connections = '/v1/connections';
  static const String _week = '/v1/week';
  static const String _messages = '/v1/messages';
  static const String _polish = '/v1/polish';
  static const String _uploads = '/v1/uploads';
  static const String _avatars = '/v1/avatars';
  static const String _league = '/v1/league';
  static const String _boards = '/v1/boards';
  static const String _models = '/v1/models';
  static const String _location = '/v1/me/location';

  /// The Suite's boards, if this engine serves them. Optional: an engine
  /// without the route, or one that fails it, still loads everything else
  /// and the leaderboard falls back to `/v1/standings`.
  Future<SuiteBoards?> _suiteBoards() async {
    try {
      final SuiteBoards boards = Decode.boards(await _api.get(_boards));
      return boards.isEmpty ? null : boards;
    } on ShiftApiException {
      return null;
    }
  }

  /// The AIs this engine has connected. Optional, like the boards: an
  /// engine without the route answers with whichever model it chooses.
  Future<List<ChatModel>> _chatModels() async {
    try {
      return Decode.rows(await _api.get(_models), 'models')
          .map(ChatModel.fromJson)
          .toList(growable: false);
    } on ShiftApiException {
      return const <ChatModel>[];
    }
  }

  @override
  Future<ShiftSnapshot> load() async {
    final Future<SuiteBoards?> boards = _suiteBoards();
    final Future<List<ChatModel>> models = _chatModels();
    // One round trip each, in parallel. A backend that would rather answer
    // in one shot can add a /v1/snapshot and this becomes a single call.
    final List<dynamic> parts = await Future.wait(<Future<dynamic>>[
      _api.get(_me),
      _api.get(_standings),
      _api.get(_trophies),
      _api.get(_vault),
      _api.get(_notes),
      _api.get(_agents),
      _api.get(_jobs),
      _api.get(_designs),
      _api.get(_connections),
      _api.get(_week),
      _api.get(_eco),
      _api.get(_avatars),
      _api.get(_league),
    ]);

    final Map<String, dynamic> week = parts[9] is Map<String, dynamic>
        ? parts[9] as Map<String, dynamic>
        : {};

    return ShiftSnapshot(
      creator: Decode.creator(parts[0] as Map<String, dynamic>),
      standings: Decode.rows(parts[1], 'standings')
          .map(StandingRow.fromJson)
          .toList(growable: false),
      trophies: Decode.trophies(parts[2]),
      ecoVault: Decode.rows(parts[10], 'ecovault')
          .map(VaultItem.fromJson)
          .toList(growable: false),
      vault: Decode.rows(parts[3], 'vault')
          .map(VaultItem.fromJson)
          .toList(growable: false),
      notes: Decode.rows(parts[4], 'notes')
          .map(Note.fromJson)
          .toList(growable: false),
      agentRuns: Decode.rows(parts[5], 'runs')
          .map(Decode.agentRun)
          .toList(growable: false),
      jobs:
          Decode.rows(parts[6], 'jobs').map(Decode.job).toList(growable: false),
      designs: Decode.rows(parts[7], 'designs')
          .map(Decode.design)
          .toList(growable: false),
      connectors: Decode.connectors(parts[8]),
      weekPool: (week['pool'] as num?)?.toInt() ?? 0,
      payoutLine: week['payoutLine'] as String? ?? '',
      avatars: Decode.rows(parts[11], 'avatars')
          .map(Decode.avatar)
          .toList(growable: false),
      league: parts[12] is Map<String, dynamic>
          ? League.fromJson(parts[12] as Map<String, dynamic>)
          : null,
      boards: await boards,
      models: await models,
    );
  }

  @override
  Future<List<ChatMessage>> send(
    String prompt, {
    bool private = false,
    String? avatarId,
    String? model,
    List<ChatTurn> history = const <ChatTurn>[],
  }) async {
    final dynamic body = await _api.post(
      _messages,
      // `private` tells the server not to retain the exchange. The client
      // already keeps it out of its own storage. The whole conversation
      // goes with every message, so the server never has to keep a thread
      // for the model to read it.
      body: <String, dynamic>{
        'prompt': prompt,
        'private': private,
        if (avatarId != null) 'avatarId': avatarId,
        if (model != null) 'model': model,
        'history': history.map((ChatTurn t) => t.toJson()).toList(),
      },
    );
    return Decode.rows(body, 'messages')
        .map(ChatMessage.fromJson)
        .toList(growable: false);
  }

  @override
  Future<String> polish(String prompt) async {
    final dynamic body;
    try {
      body =
          await _api.post(_polish, body: <String, dynamic>{'prompt': prompt});
    } on ShiftApiException catch (error) {
      // An engine with no polisher answers 404 (or 405, the route exists
      // for something else). That is not the person's problem: the brief
      // is written here instead, the same one the seeded app writes, so
      // the sparkle always does something. Anything else, from offline
      // to out of credits, is a real refusal and goes back to the bar.
      if (error.status == 404 || error.status == 405) {
        return Prompt.polish(prompt);
      }
      rethrow;
    }
    final Object? polished = body is Map<String, dynamic>
        ? (body['prompt'] ?? body['polished'] ?? body['text'])
        : null;
    if (polished is String && polished.trim().isNotEmpty) return polished;
    // It answered, but with nothing usable. Blanking the bar would lose
    // what the person typed; the local brief keeps the button honest.
    return Prompt.polish(prompt);
  }

  @override
  Future<Creator> updateHandle(String handle) async => Decode.creator(
        await _api.patch(_me, body: <String, dynamic>{'handle': handle})
            as Map<String, dynamic>,
      );

  @override
  Future<Avatar> createAvatar({
    required String uploadId,
    required String name,
  }) async =>
      Decode.avatar(
        await _api.post(
          _avatars,
          body: <String, dynamic>{'uploadId': uploadId, 'name': name},
        ) as Map<String, dynamic>,
      );

  @override
  Future<Avatar> makeAvatarPersonal(String id) async => Decode.avatar(
        await _api.post('$_avatars/$id/personal') as Map<String, dynamic>,
      );

  @override
  Future<void> deleteAvatar(String id) => _api.delete('$_avatars/$id');

  @override
  Future<League?> shareLocation({
    required double lat,
    required double lng,
  }) async {
    final dynamic body = await _api.patch(
      _location,
      body: <String, dynamic>{'lat': lat, 'lng': lng},
    );
    return body is Map<String, dynamic> ? League.fromJson(body) : null;
  }

  @override
  Future<VaultItem> saveVaultItem(String id) async => VaultItem.fromJson(
        await _api.post('$_eco/$id/save') as Map<String, dynamic>,
      );

  @override
  Future<VaultItem> unsaveVaultItem(String id) async => VaultItem.fromJson(
        await _api.delete('$_eco/$id/save') as Map<String, dynamic>,
      );

  @override
  Future<VaultItem> renameVaultItem(String id, String title) async =>
      VaultItem.fromJson(
        await _api.patch('$_vault/$id', body: <String, dynamic>{'title': title})
            as Map<String, dynamic>,
      );

  @override
  Future<VaultItem> publishVaultItem(String id) async => VaultItem.fromJson(
        await _api.post('$_vault/$id/publish') as Map<String, dynamic>,
      );

  @override
  Future<void> deleteVaultItem(String id) => _api.delete('$_vault/$id');

  @override
  Future<Note> createNote({
    required String title,
    required String body,
  }) async =>
      Note.fromJson(
        await _api.post(
          _notes,
          body: <String, dynamic>{'title': title, 'body': body},
        ) as Map<String, dynamic>,
      );

  @override
  Future<Note> saveNote(
    String id, {
    required String title,
    required String body,
  }) async =>
      Note.fromJson(
        await _api.patch(
          '$_notes/$id',
          body: <String, dynamic>{'title': title, 'body': body},
        ) as Map<String, dynamic>,
      );

  @override
  Future<void> deleteNote(String id) => _api.delete('$_notes/$id');

  @override
  Future<AgentRun> startRun(String prompt, {required String scope}) async =>
      Decode.agentRun(
        await _api.post(
          _agents,
          body: <String, dynamic>{'prompt': prompt, 'scope': scope},
        ) as Map<String, dynamic>,
      );

  @override
  Future<JobRow> startJob(String prompt, {required String scope}) async =>
      Decode.job(
        await _api.post(
          _jobs,
          body: <String, dynamic>{'prompt': prompt, 'scope': scope},
        ) as Map<String, dynamic>,
      );

  @override
  Future<AgentRun> rerunRun(String id) async => Decode.agentRun(
        await _api.post('$_agents/$id/rerun') as Map<String, dynamic>,
      );

  @override
  Future<DesignDoc> duplicateDesign(String id) async => Decode.design(
        await _api.post('$_designs/$id/duplicate') as Map<String, dynamic>,
      );

  @override
  Future<void> deleteDesign(String id) => _api.delete('$_designs/$id');

  @override
  Future<String> upload({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final dynamic body = await _api.upload(
      _uploads,
      field: 'file',
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
    );
    if (body is Map<String, dynamic> && body['id'] is String) {
      return body['id'] as String;
    }
    throw const ShiftApiException(
      ShiftApiErrorKind.malformed,
      'The upload did not come back with an id.',
    );
  }

  @override
  void dispose() => _api.close();
}

/// Picks the repository for this run. A base URL turns the real one on;
/// without one the app runs on its own catalogue, which is what it does
/// today and what the tests use.
ShiftRepository repositoryFor(
  String? baseUrl, {
  FutureOr<String?> Function()? token,
}) {
  if (baseUrl == null || baseUrl.trim().isEmpty) return SeedRepository();
  return HttpRepository(
    ApiClient(baseUrl: baseUrl.trim(), tokenProvider: token),
  );
}
