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
  static const String _threads = '/v1/threads';
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

  /// Saved chats, when the engine keeps them. Optional like the boards:
  /// any refusal (a 404 above all) means the device's copy is the one.
  Future<List<ChatThread>?> _chatThreads() async {
    try {
      return Decode.rows(await _api.get(_threads), 'threads')
          .map(ChatThread.tryParse)
          .whereType<ChatThread>()
          .toList(growable: false);
    } on ShiftApiException {
      return null;
    }
  }

  @override
  Future<void> saveThread(ChatThread thread) async {
    try {
      await _api.put('$_threads/${thread.id}', body: thread.toJson());
    } on ShiftApiException catch (error) {
      if (error.kind != ShiftApiErrorKind.notFound) rethrow;
    }
  }

  @override
  Future<void> deleteThread(String id) async {
    try {
      await _api.delete('$_threads/$id');
    } on ShiftApiException catch (error) {
      if (error.kind != ShiftApiErrorKind.notFound) rethrow;
    }
  }

  @override
  Future<ShiftSnapshot> load() async {
    final Future<SuiteBoards?> boards = _suiteBoards();
    final Future<List<ChatModel>> models = _chatModels();
    final Future<List<ChatThread>?> threads = _chatThreads();
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
      threads: await threads,
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
      // for something else). The connected AI still polishes it, through
      // the chat route every engine has. Anything else, from offline to
      // out of credits, is a real refusal and goes back to the bar.
      if (error.status == 404 || error.status == 405) {
        return _polishByChat(prompt);
      }
      rethrow;
    }
    final String? polished = _polishedFrom(body);
    // It answered with nothing usable, or with what was sent ("make a
    // video of Miami" came back as itself). Either is an engine with no
    // polisher of its own; the AI does it instead.
    if (polished == null ||
        (polished.trim() == prompt.trim() && !Prompt.isPolished(prompt))) {
      return _polishByChat(prompt);
    }
    return polished;
  }

  /// Polishing with the AI the Suite already talks to, when the engine has
  /// no /v1/polish of its own.
  ///
  /// This used to fall back to the brief lib/util/prompt.dart writes: a
  /// fixed template, which on the phone turned "What time is it" into
  /// "What time is it. Audience: someone new to this. Tone: plain and
  /// specific. …" — a question made a statement, with a brief nobody
  /// asked for. The template now only serves the demo, with no server.
  ///
  /// It goes as a private, one-off message with no history, so the
  /// thread never sees it and a server that honours `private` keeps
  /// nothing. The reply is the rewrite and only the rewrite; a preamble
  /// ("Here is a polished version:") or quotes round it are taken off.
  Future<String> _polishByChat(String prompt) async {
    final List<ChatMessage> reply =
        await send(polishInstruction(prompt), private: true);
    for (final ChatMessage m in reply) {
      if (m.author == MessageAuthor.you) continue;
      if (m.failure != null) {
        throw ShiftApiException(
          ShiftApiErrorKind.server,
          m.failure!.sentence,
        );
      }
      final String? cleaned = cleanRewrite(<String>[
        if (m.body.trim().isNotEmpty) m.body,
        ...m.bullets.map((String b) => '- $b'),
      ].join('\n'));
      if (cleaned != null) return cleaned;
    }
    throw const ShiftApiException(
      ShiftApiErrorKind.malformed,
      'The AI sent back nothing to use. Try again, or send it as it is.',
    );
  }

  /// What the AI is asked. Kept to one job: the person's own prompt,
  /// sharper, in their words, a question still a question.
  static String polishInstruction(String prompt) =>
      'Rewrite the prompt below so an AI model can do it well. Keep what '
      'the person wants, their wording where it works, and every specific '
      'they gave. Add only what is missing and would change the result '
      '(format, length, audience, style), and nothing that is not implied. '
      'If it is a question, keep it a question. Reply with the rewritten '
      'prompt only: no preamble, no quotes, no explanation.\n\n'
      'Prompt:\n$prompt';

  static final RegExp _preamble = RegExp(
    r'^\s*(?:(?:sure|okay|ok)[,!.]?\s*)?'
    r"(?:here(?:'s| is)\s+(?:the|a|your)\s+)?"
    r'(?:polished|rewritten|improved|refined|revised|clearer)\s+'
    r'(?:version|prompt)?[^:\n]{0,40}:\s*',
    caseSensitive: false,
  );

  /// The rewrite alone: a label or preamble line off the front, a code
  /// fence or quotes off the outside. Null when nothing is left.
  static String? cleanRewrite(String raw) {
    String text = raw.trim();
    final RegExpMatch? fence =
        RegExp(r'^```[a-z]*\n([\s\S]*?)\n```$').firstMatch(text);
    if (fence != null) text = fence.group(1)!.trim();
    text = text.replaceFirst(_preamble, '').trim();
    for (final (String open, String close) in <(String, String)>[
      ('"', '"'),
      ('\u201c', '\u201d'),
      ("'", "'"),
      ('`', '`'),
    ]) {
      if (text.length > 1 && text.startsWith(open) && text.endsWith(close)) {
        text = text.substring(open.length, text.length - close.length).trim();
      }
    }
    return text.isEmpty ? null : text;
  }

  /// Where a polisher puts its rewrite. The rewrite's own names come
  /// before `prompt`: a reply carrying both the original (`prompt`) and
  /// the rewrite (`polished`, `polishedPrompt`, …) used to hand back the
  /// original, because `prompt` was read first. Rex's routes wrap their
  /// answers in `data`, so that is looked inside too.
  static const List<String> _polishedKeys = <String>[
    'polished',
    'polishedPrompt',
    'polished_prompt',
    'improvedPrompt',
    'enhancedPrompt',
    'rewritten',
    'result',
    'output',
    'text',
    'prompt',
  ];

  static String? _polishedFrom(Object? body, [int depth = 0]) {
    if (body is String) return body.trim().isEmpty ? null : body;
    if (body is! Map<String, dynamic> || depth > 2) return null;
    for (final String key in _polishedKeys) {
      final Object? value = body[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    for (final String key in <String>['data', 'result']) {
      final String? inner = _polishedFrom(body[key], depth + 1);
      if (inner != null) return inner;
    }
    return null;
  }

  @override
  Future<Creator> updateHandle(String handle) async => Decode.creator(
        await _api.patch(_me, body: <String, dynamic>{'handle': handle})
            as Map<String, dynamic>,
      );

  @override
  Future<List<Avatar>> avatars() async =>
      Decode.rows(await _api.get(_avatars), 'avatars')
          .map(Decode.avatar)
          .toList(growable: false);

  @override
  Future<Avatar> createAvatar({
    required String uploadId,
    required String name,
  }) async =>
      Decode.avatar(
        await _api.post(
          _avatars,
          body: <String, dynamic>{
            'uploadId': uploadId,
            'name': name,
            // The create flow cannot be submitted without the person
            // ticking this; see docs/API.md, "POST /v1/avatars".
            'consent': true,
          },
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
