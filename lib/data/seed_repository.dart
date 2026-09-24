import 'dart:async';

import '../features/settings/connectors.dart';
import '../models/models.dart';
import '../util/prompt.dart';
import 'repository.dart';
import 'seed.dart';

/// The repository the app runs on with no server behind it: the seeded
/// catalogue, held in memory, mutated locally. This is what ships until a
/// base URL is configured, and what the tests run against.
class SeedRepository implements ShiftRepository {
  SeedRepository({this.replyDelay = const Duration(milliseconds: 650)});

  /// The beat between asking and being answered. Zero in tests.
  final Duration replyDelay;

  Creator _creator = Seed.creator;
  late List<Avatar> _avatars = List<Avatar>.of(Seed.avatars);
  late List<VaultItem> _vault = List<VaultItem>.of(Seed.vault);
  late List<VaultItem> _eco = List<VaultItem>.of(Seed.ecoVault);
  late List<Note> _notes = List<Note>.of(Seed.notes);
  late List<DesignDoc> _designs = List<DesignDoc>.of(Seed.designs);
  late List<AgentRun> _runs = List<AgentRun>.of(Seed.agentRuns);
  late List<JobRow> _jobs = List<JobRow>.of(Seed.jobs);

  @override
  Future<ShiftSnapshot> load() async => ShiftSnapshot(
        creator: _creator,
        standings: List<StandingRow>.of(Seed.standings),
        trophies: List<Trophy>.of(Seed.trophies),
        vault: List<VaultItem>.of(_vault),
        // Your own published pieces stand alongside everyone else's, which
        // is what makes EcoVault one gallery rather than two.
        ecoVault: <VaultItem>[
          ..._vault.where((VaultItem v) => v.published),
          ..._eco,
        ]..sort(
            (VaultItem a, VaultItem b) => b.createdAt.compareTo(a.createdAt),
          ),
        notes: List<Note>.of(_notes),
        agentRuns: List<AgentRun>.of(_runs),
        jobs: List<JobRow>.of(_jobs),
        designs: List<DesignDoc>.of(_designs),
        connectors: List<Connector>.of(ConnectorCatalog.all),
        weekPool: Seed.weekPool,
        payoutLine: Seed.payoutLine,
        avatars: List<Avatar>.of(_avatars),
        league: Seed.league,
      );

  @override
  Future<List<ChatMessage>> send(
    String prompt, {
    bool private = false,
    String? avatarId,
    String? model,
    List<ChatTurn> history = const <ChatTurn>[],
    Future<void>? cancel,
    void Function(String soFar)? onText,
  }) async {
    if (replyDelay > Duration.zero) await Future<void>.delayed(replyDelay);
    final String stamp = DateTime.now().microsecondsSinceEpoch.toString();
    return Seed.cannedReply
        .map(
          (ChatMessage m) => ChatMessage(
            id: '${m.id}-$stamp',
            author: m.author,
            body: m.body,
            eyebrow: m.eyebrow,
            bullets: m.bullets,
            attachment: m.attachment,
            failure: m.failure,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<String> polish(String prompt) async => Prompt.polish(prompt);

  @override
  Future<Creator> updateHandle(String handle) async {
    _creator = _creator.copyWith(handle: handle);
    return _creator;
  }

  /// An id nobody has is a 404, not a crash: the code above this only
  /// knows how to handle [ShiftApiException].
  static Never _missing(String what, String id) => throw ShiftApiException(
        ShiftApiErrorKind.notFound,
        'No $what with id $id.',
        status: 404,
      );

  T _find<T>(List<T> list, bool Function(T) match, String what, String id) {
    for (final T item in list) {
      if (match(item)) return item;
    }
    _missing(what, id);
  }

  // The demo keeps no chats beyond the device: it cannot chat at all
  // without an account.
  @override
  Future<void> saveThread(ChatThread thread) async {}

  @override
  Future<void> deleteThread(String id) async {}

  @override
  Future<List<VaultItem>> vault() async => List<VaultItem>.of(_vault);

  @override
  Future<List<Avatar>> avatars() async => List<Avatar>.of(_avatars);

  @override
  Future<Avatar> createAvatar({
    required String uploadId,
    required String name,
  }) async {
    // Nothing here actually trains anything — there is no HeyGen behind
    // the seeded catalogue — so the row sits in `training` forever, which
    // is exactly the state the gallery needs to be able to draw.
    final Avatar avatar = Avatar(
      id: 'avatar-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Avatar' : name.trim(),
      status: AvatarStatus.training,
    );
    _avatars = <Avatar>[..._avatars, avatar];
    return avatar;
  }

  @override
  Future<Avatar> makeAvatarPersonal(String id) async {
    final Avatar target = _find<Avatar>(
      _avatars,
      (Avatar a) => a.id == id,
      'avatar',
      id,
    );
    final Avatar next = target.copyWith(personal: true);
    _avatars = _avatars
        .map((Avatar a) => a.id == id ? next : a.copyWith(personal: false))
        .toList();
    return next;
  }

  @override
  Future<void> deleteAvatar(String id) async {
    _avatars = _avatars.where((Avatar a) => a.id != id).toList();
  }

  @override
  Future<League?> shareLocation({
    required double lat,
    required double lng,
  }) async =>
      Seed.league;

  VaultItem _setSaved(String id, bool saved) {
    final VaultItem target = _find<VaultItem>(
      <VaultItem>[..._eco, ..._vault],
      (VaultItem v) => v.id == id,
      'vault item',
      id,
    );
    final VaultItem next = target.copyWith(saved: saved);
    _eco = _eco.map((VaultItem v) => v.id == id ? next : v).toList();
    _vault = _vault.map((VaultItem v) => v.id == id ? next : v).toList();
    return next;
  }

  @override
  Future<VaultItem> saveVaultItem(String id) async => _setSaved(id, true);

  @override
  Future<VaultItem> unsaveVaultItem(String id) async => _setSaved(id, false);

  @override
  Future<VaultItem> renameVaultItem(String id, String title) async {
    final VaultItem next = _find<VaultItem>(
      _vault,
      (VaultItem v) => v.id == id,
      'vault item',
      id,
    ).copyWith(title: title);
    _vault = _vault.map((VaultItem v) => v.id == id ? next : v).toList();
    return next;
  }

  @override
  Future<VaultItem> publishVaultItem(String id) async {
    final VaultItem next = _find<VaultItem>(
      _vault,
      (VaultItem v) => v.id == id,
      'vault item',
      id,
    ).copyWith(published: true);
    _vault = _vault.map((VaultItem v) => v.id == id ? next : v).toList();
    return next;
  }

  @override
  Future<void> deleteVaultItem(String id) async {
    _vault = _vault.where((VaultItem v) => v.id != id).toList();
  }

  @override
  Future<Note> createNote({
    required String title,
    required String body,
  }) async {
    final Note note = Note(
      id: 'note-${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Untitled' : title.trim(),
      body: body,
      editedAt: DateTime.now(),
    );
    _notes = <Note>[note, ..._notes];
    return note;
  }

  @override
  Future<Note> saveNote(
    String id, {
    required String title,
    required String body,
  }) async {
    final Note next =
        _find<Note>(_notes, (Note n) => n.id == id, 'note', id).copyWith(
      title: title.trim().isEmpty ? 'Untitled' : title.trim(),
      body: body,
      editedAt: DateTime.now(),
    );
    _notes = _notes.map((Note n) => n.id == id ? next : n).toList();
    return next;
  }

  @override
  Future<void> deleteNote(String id) async {
    _notes = _notes.where((Note n) => n.id != id).toList();
  }

  /// The first line of the ask, which is what a row is titled by.
  static String _titleFrom(String prompt) {
    final String flat = prompt.split('\n').first.trim();
    if (flat.isEmpty) return 'Untitled task';
    return flat.length <= 72 ? flat : '${flat.substring(0, 71)}\u2026';
  }

  @override
  Future<AgentRun> startRun(String prompt, {required String scope}) async {
    final AgentRun run = AgentRun(
      id: 'r-${DateTime.now().microsecondsSinceEpoch}',
      title: _titleFrom(prompt),
      detail: 'Just handed over',
      status: RunStatus.working,
      scope: scope,
    );
    _runs = <AgentRun>[run, ..._runs];
    return run;
  }

  @override
  Future<JobRow> startJob(String prompt, {required String scope}) async {
    final JobRow job = JobRow(
      id: 'j-${DateTime.now().microsecondsSinceEpoch}',
      title: _titleFrom(prompt),
      detail: 'Queued \u00b7 $scope',
      status: RunStatus.working,
      scope: scope,
    );
    _jobs = <JobRow>[job, ..._jobs];
    return job;
  }

  @override
  Future<AgentRun> rerunRun(String id) async {
    final AgentRun before = _find<AgentRun>(
      _runs,
      (AgentRun r) => r.id == id,
      'run',
      id,
    );
    final AgentRun next = AgentRun(
      id: before.id,
      title: before.title,
      detail: 'Started again',
      status: RunStatus.working,
      scope: before.scope,
    );
    _runs = _runs.map((AgentRun r) => r.id == id ? next : r).toList();
    return next;
  }

  @override
  Future<DesignDoc> duplicateDesign(String id) async {
    final DesignDoc source =
        _find<DesignDoc>(_designs, (DesignDoc d) => d.id == id, 'design', id);
    final DesignDoc copy = DesignDoc(
      id: 'design-${DateTime.now().microsecondsSinceEpoch}',
      title: '${source.title} copy',
      versions: 1,
      kindLabel: source.kindLabel,
    );
    final int at = _designs.indexOf(source);
    _designs = <DesignDoc>[
      ..._designs.sublist(0, at + 1),
      copy,
      ..._designs.sublist(at + 1),
    ];
    return copy;
  }

  @override
  Future<void> deleteDesign(String id) async {
    _designs = _designs.where((DesignDoc d) => d.id != id).toList();
  }

  @override
  Future<String> upload({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async =>
      'local-${DateTime.now().microsecondsSinceEpoch}-$fileName';

  @override
  void dispose() {}
}
