import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/modes.dart';
import '../data/auth/auth_service.dart';
import '../data/auth/token_store.dart';
import '../data/backend.dart';
import '../data/repository.dart';
import '../data/seed.dart';
import '../data/seed_repository.dart';
import '../features/settings/avatar.dart';
import '../features/settings/connectors.dart';
import '../models/models.dart';
import '../theme/tokens.dart';

/// Storage keys. Everything money related persists so a reload never resets
/// the account. Nothing else writes these keys, and a key this app did not
/// write in a session is never cleared.
abstract final class StoreKeys {
  /// Whole app state blob: theme, active tab, earnings ledger, trophies,
  /// vault items, notes.
  static const String app = 'shift.app.v1';

  /// The avatar photo and its framing.
  static const String photoAvatar = 'shift.photoAvatar';

  /// Image picker scratch.
  static const String pickImage = 'shift-pick-image';

  /// Backend base URL override.
  static const String backend = 'shift-backend';
}

/// One store for the whole client. Read once on mount, written back
/// debounced on change; private chat content never reaches it.
class AppState extends ChangeNotifier {
  AppState._(this._prefs, Map<String, dynamic> blob, this._repo, this._snap) {
    themeId = ShiftThemeIdLabel.parse(blob['theme'] as String?);
    // Stored as the disabled set rather than the enabled one, so a feature
    // added by a later version is on by default instead of silently
    // missing for everyone who already has a blob.
    _disabled = <ShiftFeature>{
      for (final Object? raw in (blob['disabledFeatures'] as List<Object?>?) ??
          const <Object?>[])
        if (ShiftFeature.parse(raw as String?) case final ShiftFeature f) f,
    };
    surface = Surface.parse(blob['surface'] as String?);
    mode = ShiftMode.parse(blob['mode'] as String?);
    // The blob can name a surface whose feature was switched off in a
    // previous session. Opening straight onto a screen whose sidebar row
    // is gone leaves no way back, so fall back to Suite.
    if (!isEnabled(surface.feature)) surface = Surface.suite;
    if (!isEnabled(mode.feature)) mode = ShiftMode.suite;
    signedIn = blob['signedIn'] as bool? ?? true;
    _backendBaseUrl = _prefs.getString(StoreKeys.backend);
    avatar = _readAvatar();

    // What the repository answered is the truth; the stored blob is a
    // local cache on top of it, so that a reload with no network still
    // draws what was last seen.
    standings = _listOr<StandingRow>(
      blob['standings'],
      StandingRow.fromJson,
      _snap.standings,
    );
    // The cached blob is only a faster redraw of what the engine already
    // said. It is keyed to nothing, so it is only trusted in seeded mode
    // or when the engine has just answered — never as a stand-in for an
    // account whose data has not arrived.
    vault = _listOr<VaultItem>(blob['vault'], VaultItem.fromJson, _snap.vault);
    ecoVault = _listOr<VaultItem>(
      blob['ecoVault'],
      VaultItem.fromJson,
      _snap.ecoVault,
    );
    notes = _listOr<Note>(blob['notes'], Note.fromJson, _snap.notes);

    final Map<String, dynamic> unlocked =
        (blob['trophies'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    trophies = _snap.trophies.map((Trophy t) {
      final String? stamp = unlocked[t.id] as String?;
      if (stamp == null) return t;
      return t.copyWith(earnedOn: DateTime.tryParse(stamp));
    }).toList();

    agentRuns = List<AgentRun>.of(_snap.agentRuns);
    jobs = List<JobRow>.of(_snap.jobs);
    designs = List<DesignDoc>.of(_snap.designs);
    avatars = List<Avatar>.of(_snap.avatars);
    messages = <ChatMessage>[];

    // Which scope each Agents tab was left pointed at. An unknown one
    // (a repo since disconnected) falls back to the default.
    final String? savedAgent = blob['agentScope'] as String?;
    if (savedAgent != null && Seed.agentScopes.contains(savedAgent)) {
      agentScope = savedAgent;
    }
    final String? savedJob = blob['jobScope'] as String?;
    if (savedJob != null && Seed.jobScopes.contains(savedJob)) {
      jobScope = savedJob;
    }
  }

  final ShiftRepository _repo;
  ShiftSnapshot _snap;

  /// The engine behind this run. Swapping it is what wiring a server means.
  ShiftRepository get repository => _repo;

  /// True when nothing is behind the app but the seeded catalogue — no
  /// backend configured. Screens say so rather than passing sample data
  /// off as the person's own.
  bool seededDemo = true;

  /// Set when the last call to the engine failed, so a screen can say so
  /// rather than showing an empty list as though it were the answer.
  ShiftApiException? lastError;

  /// True while a refresh is in flight.
  bool refreshing = false;

  /// Re-reads everything from the engine. Local edits that have not been
  /// pushed are overwritten, which is the point — the server is the truth.
  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    lastError = null;
    notifyListeners();
    try {
      _snap = await _repo.load();
      standings = List<StandingRow>.of(_snap.standings);
      ecoVault = List<VaultItem>.of(_snap.ecoVault);
      trophies = List<Trophy>.of(_snap.trophies);
      vault = List<VaultItem>.of(_snap.vault);
      notes = List<Note>.of(_snap.notes);
      agentRuns = List<AgentRun>.of(_snap.agentRuns);
      jobs = List<JobRow>.of(_snap.jobs);
      designs = List<DesignDoc>.of(_snap.designs);
      avatars = List<Avatar>.of(_snap.avatars);
    } on ShiftApiException catch (error) {
      // Keep what is on screen. An empty list would read as "you have
      // nothing", which is a different and wrong statement.
      lastError = error;
    } finally {
      refreshing = false;
      _changed();
    }
  }

  /// Runs a write against the engine and rolls the screen back if it is
  /// refused, so the UI never keeps a change the server did not take.
  ///
  /// Returns whether the write took. A rolled-back button that says
  /// nothing looks broken, so every caller reports false to the person.
  Future<bool> _push(
      Future<void> Function() write, VoidCallback rollback) async {
    try {
      await write();
      lastError = null;
      return true;
    } on ShiftApiException catch (error) {
      lastError = error;
      rollback();
      _changed();
      return false;
    }
  }

  /// Builds the store. [repository] is the engine; leaving it out picks
  /// one from the saved base URL, which is the seeded catalogue until a
  /// URL is set.
  static Future<AppState> load({
    ShiftRepository? repository,
    Backend? engine,
    TokenStore? tokenStore,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> blob = <String, dynamic>{};
    final String? raw = prefs.getString(StoreKeys.app);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        // A blob from an older shape is read past rather than migrated: the
        // rows in it describe screens this build no longer has.
        if (decoded is Map<String, dynamic> && decoded['v'] == _blobVersion) {
          blob = decoded;
        }
      } on FormatException {
        // A blob this build cannot read is left alone rather than cleared:
        // an older client may still want it.
        blob = <String, dynamic>{};
      }
    }
    final String? url = prefs.getString(StoreKeys.backend);
    final Backend backend =
        engine ?? await Backend.connect(url, store: tokenStore);
    final ShiftRepository repo = repository ?? backend.repository;

    // With a backend configured, the seeded catalogue is somebody else's
    // work. An engine that cannot be reached leaves the screens empty and
    // says why; it does not hand over a stranger's vault and earnings.
    final bool seeded = backend.seeded;

    ShiftSnapshot snapshot;
    ShiftApiException? failure;
    if (!seeded && !backend.auth.signedIn) {
      // Nothing to fetch and nobody to fetch it for. The gate is next.
      snapshot = emptySnapshot();
    } else {
      try {
        snapshot = await repo.load();
      } on ShiftApiException catch (error) {
        failure = error;
        snapshot = seeded ? await SeedRepository().load() : emptySnapshot();
      }
    }

    // The cached blob is keyed to an account. It is read back only when
    // it belongs to the account that just answered — a device that two
    // people have signed into must never show one of them the other's
    // vault, and a failed load has no account to check against, so it
    // gets nothing.
    if (!seeded) {
      final bool sameAccount = failure == null &&
          snapshot.creator.email.isNotEmpty &&
          blob['account'] == snapshot.creator.email;
      if (!sameAccount) {
        blob = Map<String, dynamic>.of(blob)
          ..remove('vault')
          ..remove('ecoVault')
          ..remove('notes')
          ..remove('standings')
          ..remove('trophies');
      }
    }

    final AppState state = AppState._(prefs, blob, repo, snapshot);
    state.lastError = failure;
    state.seededDemo = seeded;
    state._auth = backend.auth;
    if (!seeded) state.signedIn = backend.auth.signedIn;
    return state;
  }

  static const int _blobVersion = 2;

  final SharedPreferences _prefs;
  Timer? _writeTimer;
  Future<void>? _reply;

  // Shell ---------------------------------------------------------------
  late ShiftThemeId themeId;
  late Surface surface;
  late ShiftMode mode;
  late bool signedIn;
  bool privateChat = false;

  /// Off unless a build actually has an update to announce.
  bool updateBannerVisible = false;

  /// The sidebar starts out of the way; the hamburger opens and closes it.
  bool sidebarCollapsed = true;

  // Content -------------------------------------------------------------
  late List<StandingRow> standings;
  late List<Trophy> trophies;
  late List<VaultItem> vault;

  /// Everyone's published work. Your own published pieces are in here too,
  /// so the gallery reads the same for everyone looking at it.
  late List<VaultItem> ecoVault;
  late List<Note> notes;
  late List<AgentRun> agentRuns;
  late List<JobRow> jobs;
  late List<DesignDoc> designs;
  late List<Avatar> avatars;
  late List<ChatMessage> messages;

  /// The one avatar shown as the profile picture and on the leaderboard,
  /// when there is one.
  Avatar? get personalAvatar =>
      avatars.where((Avatar a) => a.personal).firstOrNull;

  /// Which avatar the next thing sent to the Suite should be generated as.
  /// Null means whatever the engine answers with by default.
  String? activeAvatarId;

  /// Agents has two tabs: the runs against a repository, and the jobs
  /// running in a folder.
  bool showingJobs = false;

  /// What each tab is pointed at. The picker changes these, and the lists
  /// below are filtered by them.
  String agentScope = Seed.agentScope;
  String jobScope = Seed.jobScope;

  /// Text waiting to be dropped into the next composer that builds — how
  /// Vault hands a prompt back to Suite.
  String? composerDraft;

  /// True between a message going out and its answer landing.
  bool thinking = false;

  VaultScope vaultScope = VaultScope.mine;
  String? selectedVaultId;

  /// The photo avatar, once one has been set. Null means initials. It
  /// lives in its own key: a picture is far bigger than the rest of the
  /// state and should not be rewritten on every unrelated change.
  AvatarPhoto? avatar;

  String? _backendBaseUrl;

  String? get backendBaseUrl => _backendBaseUrl;

  /// The weekly pool and the line under it, as the engine reports them.
  int get weekPool => _snap.weekPool;
  String get payoutLine => _snap.payoutLine;

  /// The connector catalogue the engine knows about.
  List<Connector> get connectors => _snap.connectors;

  // Derived -------------------------------------------------------------
  /// Your row on the board, or null before the board has one — a new
  /// account, or a week that has not scored yet. This used to fall back to
  /// `standings.last`, which threw on an empty board and, worse, pointed
  /// at a stranger's row when it did not.
  StandingRow? get you =>
      standings.where((StandingRow r) => r.isYou).firstOrNull;

  StandingRow? get target {
    final int? rank = you?.rank;
    if (rank == null || rank <= 1) return null;
    return standings.where((StandingRow r) => r.rank == rank - 1).firstOrNull;
  }

  StandingRow? get chaser {
    final int? rank = you?.rank;
    if (rank == null) return null;
    return standings.where((StandingRow r) => r.rank == rank + 1).firstOrNull;
  }

  List<StandingRow> get podium =>
      standings.where((StandingRow r) => r.rank <= 3).toList();

  List<StandingRow> get rest =>
      standings.where((StandingRow r) => r.rank > 3).toList();

  int get trophiesEarned => trophies.where((Trophy t) => t.earned).length;

  int get trophyPoints => trophies
      .where((Trophy t) => t.earned)
      .fold(0, (int sum, Trophy t) => sum + t.points);

  /// What you have hearted in EcoVault. Someone else's work, kept where
  /// you can find it again — which is the whole point of the heart.
  List<VaultItem> get savedFromEco => ecoVault
      .where((VaultItem v) => v.saved && !v.mine)
      .toList(growable: false);

  /// My vault is what you made, plus what you saved. Saved pieces keep
  /// their author and are drawn differently, so the list never implies
  /// you made something you did not.
  List<VaultItem> get myVault {
    final List<VaultItem> all = <VaultItem>[...vault, ...savedFromEco]
      ..sort((VaultItem a, VaultItem b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  List<VaultItem> get visibleVault => switch (vaultScope) {
        VaultScope.mine => myVault,
        VaultScope.eco => ecoVault,
      };

  /// Looked up across both lists, because the detail panel opens over
  /// whichever scope you were in.
  VaultItem? get selectedVaultItem {
    if (selectedVaultId == null) return null;
    for (final VaultItem v in <VaultItem>[...vault, ...ecoVault]) {
      if (v.id == selectedVaultId) return v;
    }
    return null;
  }

  /// The features switched off in Settings. Empty means everything is on,
  /// which is what a new account gets.
  late Set<ShiftFeature> _disabled;

  /// True when [feature] is switched on. A null feature is something that
  /// cannot be switched off (Suite, Settings), so it is always true.
  bool isEnabled(ShiftFeature? feature) =>
      feature == null || !_disabled.contains(feature);

  /// The modes whose row belongs in the sidebar right now.
  List<ShiftMode> get visibleModes => ShiftMode.values
      .where((ShiftMode m) => isEnabled(m.feature))
      .toList(growable: false);

  /// The workspace rows that belong in the sidebar right now. Can be empty,
  /// and the sidebar drops its group heading when it is.
  List<Surface> get visibleWorkspace => kWorkspaceSurfaces
      .where((Surface s) => isEnabled(s.feature))
      .toList(growable: false);

  // Commands ------------------------------------------------------------
  void setTheme(ShiftThemeId id) {
    if (themeId == id) return;
    themeId = id;
    _changed();
  }

  void setSurface(Surface next) {
    // A switched-off surface is not navigable. The rows and links that
    // lead to one are hidden, but guarding here too means a stale route
    // cannot land on a screen with no way out of it.
    final Surface target = isEnabled(next.feature) ? next : Surface.suite;
    if (surface == target) return;
    surface = target;
    _changed();
  }

  void setMode(ShiftMode next) {
    final ShiftMode target = isEnabled(next.feature) ? next : ShiftMode.suite;
    mode = target;
    surface = target.surface;
    _changed();
  }

  /// Switch a feature on or off. Turning off whatever is currently open
  /// moves to Suite rather than leaving the screen up with its row gone.
  void setFeatureEnabled(ShiftFeature feature, bool enabled) {
    if (enabled == isEnabled(feature)) return;
    if (enabled) {
      _disabled.remove(feature);
    } else {
      _disabled.add(feature);
      if (surface.feature == feature) surface = Surface.suite;
      if (mode.feature == feature) mode = ShiftMode.suite;
    }
    _changed();
  }

  void togglePrivateChat() {
    privateChat = !privateChat;
    _changed();
  }

  void dismissUpdateBanner() {
    updateBannerVisible = false;
    _changed();
  }

  void toggleSidebar() {
    sidebarCollapsed = !sidebarCollapsed;
    _changed();
  }

  /// Save the avatar photo and its framing, or clear it by passing null.
  /// This one writes straight through: a picture is worth not losing to a
  /// reload landing inside the debounce window.
  void setAvatar(AvatarPhoto? photo) {
    avatar = photo;
    if (photo == null) {
      _prefs.remove(StoreKeys.photoAvatar);
    } else {
      _prefs.setString(StoreKeys.photoAvatar, jsonEncode(photo.toJson()));
    }
    notifyListeners();
  }

  AvatarPhoto? _readAvatar() {
    final String? raw = _prefs.getString(StoreKeys.photoAvatar);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AvatarPhoto.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  void setVaultScope(VaultScope scope) {
    vaultScope = scope;
    selectedVaultId = null;
    _changed();
  }

  void selectVaultItem(String? id) {
    selectedVaultId = id;
    _changed();
  }

  /// Hearts a piece, or takes the heart off. Applied straight away and
  /// rolled back if the engine refuses, like every other write.
  ///
  /// Saving copies nothing: the piece stays the author's, and what you
  /// get is a bookmark that shows up in your vault.
  Future<bool> toggleSaved(String id) async {
    final VaultItem? item = <VaultItem>[...ecoVault, ...vault]
        .where((VaultItem v) => v.id == id)
        .firstOrNull;
    if (item == null) return false;

    final bool next = !item.saved;
    final List<VaultItem> beforeEco = ecoVault;
    final List<VaultItem> beforeMine = vault;

    VaultItem apply(VaultItem v) => v.id == id ? v.copyWith(saved: next) : v;
    ecoVault = ecoVault.map(apply).toList();
    vault = vault.map(apply).toList();
    _changed();

    return _push(
      () => next ? _repo.saveVaultItem(id) : _repo.unsaveVaultItem(id),
      () {
        ecoVault = beforeEco;
        vault = beforeMine;
      },
    );
  }

  Future<bool> renameVaultItem(String id, String title) async {
    final List<VaultItem> before = vault;
    vault = vault
        .map((VaultItem v) => v.id == id ? v.copyWith(title: title) : v)
        .toList();
    _changed();
    return _push(
      () => _repo.renameVaultItem(id, title),
      () => vault = before,
    );
  }

  Future<bool> publishVaultItem(String id) async {
    final List<VaultItem> before = vault;
    vault = vault
        .map((VaultItem v) => v.id == id ? v.copyWith(published: true) : v)
        .toList();
    _changed();
    return _push(() => _repo.publishVaultItem(id), () => vault = before);
  }

  Future<bool> deleteVaultItem(String id) async {
    final List<VaultItem> before = vault;
    final String? selected = selectedVaultId;
    vault = vault.where((VaultItem v) => v.id != id).toList();
    if (selectedVaultId == id) selectedVaultId = null;
    _changed();
    return _push(
      () => _repo.deleteVaultItem(id),
      () {
        vault = before;
        selectedVaultId = selected;
      },
    );
  }

  /// Vault's "Re-run": the prompt that made this goes back into the Suite
  /// composer, where it can be changed before it is sent again.
  void reusePrompt(String prompt) {
    composerDraft = prompt;
    selectedVaultId = null;
    mode = ShiftMode.suite;
    surface = ShiftMode.suite.surface;
    _changed();
  }

  /// Read once by whichever composer builds next, then cleared, so going
  /// back to Suite later does not re-fill the bar.
  String? takeComposerDraft() {
    final String? draft = composerDraft;
    composerDraft = null;
    return draft;
  }

  Future<bool> duplicateDesign(String id) async {
    final int at = designs.indexWhere((DesignDoc d) => d.id == id);
    if (at < 0) return false;
    final List<DesignDoc> before = designs;
    final DesignDoc source = designs[at];
    final DesignDoc draft = DesignDoc(
      id: 'design-${DateTime.now().microsecondsSinceEpoch}',
      title: '${source.title} copy',
      versions: 1,
      kindLabel: source.kindLabel,
    );
    designs = <DesignDoc>[
      ...designs.sublist(0, at + 1),
      draft,
      ...designs.sublist(at + 1),
    ];
    _changed();

    bool took = true;
    try {
      final DesignDoc saved = await _repo.duplicateDesign(id);
      designs =
          designs.map((DesignDoc d) => d.id == draft.id ? saved : d).toList();
      lastError = null;
    } on ShiftApiException catch (error) {
      lastError = error;
      designs = before;
      took = false;
    }
    _changed();
    return took;
  }

  Future<bool> deleteDesign(String id) async {
    final List<DesignDoc> before = designs;
    designs = designs.where((DesignDoc d) => d.id != id).toList();
    _changed();
    return _push(() => _repo.deleteDesign(id), () => designs = before);
  }

  /// Uploads a photo and starts training a new avatar from it. This waits
  /// for the engine rather than showing a row with a made-up id or a
  /// training state it has not actually confirmed — same reasoning as
  /// [addNote]. Null means the engine refused, and [lastError] says why.
  Future<Avatar?> createAvatar(
    List<int> bytes, {
    required String name,
    String fileName = 'avatar.png',
    String mimeType = 'image/png',
  }) async {
    try {
      final String uploadId = await _repo.upload(
        fileName: fileName,
        mimeType: mimeType,
        bytes: bytes,
      );
      final Avatar created = await _repo.createAvatar(
        uploadId: uploadId,
        name: name,
      );
      avatars = <Avatar>[...avatars, created];
      lastError = null;
      _changed();
      return created;
    } on ShiftApiException catch (error) {
      lastError = error;
      _changed();
      return null;
    }
  }

  /// Makes [id] the one shown as the profile picture and on the
  /// leaderboard, in place of whichever avatar was personal before.
  Future<bool> makeAvatarPersonal(String id) async {
    final List<Avatar> before = avatars;
    avatars = avatars
        .map((Avatar a) => a.copyWith(personal: a.id == id))
        .toList();
    activeAvatarId ??= id;
    _changed();
    return _push(
      () => _repo.makeAvatarPersonal(id),
      () => avatars = before,
    );
  }

  Future<bool> deleteAvatar(String id) async {
    final List<Avatar> before = avatars;
    avatars = avatars.where((Avatar a) => a.id != id).toList();
    if (activeAvatarId == id) activeAvatarId = null;
    _changed();
    return _push(() => _repo.deleteAvatar(id), () => avatars = before);
  }

  /// Which avatar the next Suite message should be generated as. Null
  /// clears it back to the engine's default.
  void setActiveAvatar(String? id) {
    if (activeAvatarId == id) return;
    activeAvatarId = id;
    _changed();
  }

  void showJobs(bool value) {
    if (showingJobs == value) return;
    showingJobs = value;
    _changed();
  }

  /// Agents and Jobs each work inside a scope, and the picker changes it
  /// for whichever tab is showing.
  void setScope(String scope) {
    if (showingJobs) {
      if (jobScope == scope) return;
      jobScope = scope;
    } else {
      if (agentScope == scope) return;
      agentScope = scope;
    }
    _changed();
  }

  /// Rows in the scope showing. A row with no scope of its own predates
  /// scoping and belongs to the default, which is where it is listed.
  List<AgentRun> get visibleRuns => agentRuns
      .where((AgentRun r) => (r.scope ?? Seed.agentScope) == agentScope)
      .toList(growable: false);

  List<JobRow> get visibleJobs => jobs
      .where((JobRow j) => (j.scope ?? Seed.jobScope) == jobScope)
      .toList(growable: false);

  /// The Agents composer hands a task over for real: a row appears in the
  /// scope showing, working, and stays there.
  Future<bool> startAgentWork(String prompt) async {
    final String text = prompt.trim();
    if (text.isEmpty) return false;
    try {
      if (showingJobs) {
        final JobRow job = await _repo.startJob(text, scope: jobScope);
        jobs = <JobRow>[job, ...jobs];
      } else {
        final AgentRun run = await _repo.startRun(text, scope: agentScope);
        agentRuns = <AgentRun>[run, ...agentRuns];
      }
      lastError = null;
      _changed();
      return true;
    } on ShiftApiException catch (error) {
      lastError = error;
      _changed();
      return false;
    }
  }

  /// Re-run really does put the run back to working rather than saying so.
  Future<bool> rerunAgent(String id) async {
    final List<AgentRun> before = agentRuns;
    agentRuns = agentRuns
        .map(
          (AgentRun r) => r.id == id
              ? AgentRun(
                  id: r.id,
                  title: r.title,
                  detail: 'Started again',
                  status: RunStatus.working,
                  scope: r.scope,
                )
              : r,
        )
        .toList();
    _changed();
    return _push(() => _repo.rerunRun(id), () => agentRuns = before);
  }

  Future<bool> deleteNote(String id) async {
    final List<Note> before = notes;
    notes = notes.where((Note n) => n.id != id).toList();
    _changed();
    return _push(() => _repo.deleteNote(id), () => notes = before);
  }

  /// New notes go on top, where you will look for them.
  ///
  /// This waits for the engine rather than showing a row with a made-up
  /// id: the id is what every later edit is addressed to, so handing the
  /// caller a temporary one only moves the failure somewhere harder to see.
  /// Null means the engine refused, and [lastError] says why.
  Future<Note?> addNote({String title = '', String body = ''}) async {
    try {
      final Note saved = await _repo.createNote(
        title: title.trim().isEmpty ? 'Untitled' : title.trim(),
        body: body,
      );
      notes = <Note>[saved, ...notes];
      lastError = null;
      _changed();
      return saved;
    } on ShiftApiException catch (error) {
      lastError = error;
      _changed();
      return null;
    }
  }

  Future<bool> saveNote(
    String id, {
    required String title,
    required String body,
  }) async {
    final List<Note> before = notes;
    notes = notes
        .map(
          (Note n) => n.id == id
              ? n.copyWith(
                  title: title.trim().isEmpty ? 'Untitled' : title.trim(),
                  body: body,
                  editedAt: DateTime.now(),
                )
              : n,
        )
        .toList();
    _changed();
    return _push(
      () => _repo.saveNote(id, title: title, body: body),
      () => notes = before,
    );
  }

  late AuthController _auth;

  /// Who is signed in, as the engine reported them. In seeded mode this
  /// is the catalogue's creator.
  Creator get creator => _auth.creator ?? _snap.creator;

  /// Writes a creator wherever [creator] reads it from: the session when
  /// signed in against a real backend, the snapshot otherwise. Fire-and-
  /// forget on the session side — the session field updates synchronously,
  /// only the keychain write trails behind.
  void _applyCreator(Creator next) {
    if (_auth.creator != null) {
      unawaited(_auth.updateCreator(next));
    } else {
      _snap = ShiftSnapshot(
        creator: next,
        standings: _snap.standings,
        trophies: _snap.trophies,
        vault: _snap.vault,
        ecoVault: _snap.ecoVault,
        notes: _snap.notes,
        agentRuns: _snap.agentRuns,
        jobs: _snap.jobs,
        designs: _snap.designs,
        connectors: _snap.connectors,
        weekPool: _snap.weekPool,
        payoutLine: _snap.payoutLine,
        avatars: _snap.avatars,
      );
    }
  }

  /// Changes the username shown on the account card. Optimistic like every
  /// other write here: rolled back if the server refuses it.
  Future<bool> updateHandle(String handle) async {
    final Creator before = creator;
    final String trimmed = handle.trim();
    _applyCreator(before.copyWith(handle: trimmed));
    _changed();
    return _push(
      () async => _applyCreator(await _repo.updateHandle(trimmed)),
      () => _applyCreator(before),
    );
  }

  /// True while a sign-in is in flight, so the gate can say so.
  bool signingIn = false;

  /// Signs in for real and pulls that account's data. Returns null on
  /// success, or the sentence to show under the form.
  Future<String?> signIn(String email, String password) async {
    if (signingIn) return null;
    signingIn = true;
    lastError = null;
    _changed();
    try {
      await _auth.signIn(email: email, password: password);
      signedIn = true;
      signingIn = false;
      _changed();
      // The screens are empty until this lands — this is the account's
      // first read, not a background refresh.
      await refresh();
      return null;
    } on ShiftApiException catch (error) {
      signingIn = false;
      _changed();
      return error.message;
    }
  }

  /// Signing out empties the screens and the cache with them. Leaving a
  /// vault on the device for the next person to sign in is the same leak
  /// as showing them the seeded one.
  Future<void> signOut() async {
    await _auth.signOut();
    signedIn = false;
    selectedVaultId = null;
    messages = <ChatMessage>[];
    if (!seededDemo) {
      vault = <VaultItem>[];
      ecoVault = <VaultItem>[];
      notes = <Note>[];
      standings = <StandingRow>[];
      trophies = <Trophy>[];
      agentRuns = <AgentRun>[];
      jobs = <JobRow>[];
      designs = <DesignDoc>[];
      avatars = <Avatar>[];
      _snap = emptySnapshot();
    }
    activeAvatarId = null;
    _prefs.remove(StoreKeys.photoAvatar);
    avatar = null;
    await _write();
    _changed();
  }

  /// Deletes the account and everything under it. Apple requires this to
  /// be reachable from inside the app when the app can create accounts
  /// (Guideline 5.1.1(v)). Returns null on success, or what went wrong.
  Future<String?> deleteAccount() async {
    try {
      await _auth.deleteAccount();
    } on ShiftApiException catch (error) {
      return error.message;
    }
    await signOut();
    return null;
  }

  void setBackendBaseUrl(String? url) {
    _backendBaseUrl = url;
    if (url == null || url.isEmpty) {
      _prefs.remove(StoreKeys.backend);
    } else {
      _prefs.setString(StoreKeys.backend, url);
    }
    notifyListeners();
  }

  /// A sent message, and the answer it gets a beat later. In a private chat
  /// both stay in memory and are never written to storage.
  ///
  /// The answer is canned: patches 0013 and 0014 are not deployed, so there
  /// is nothing to ask. It is the real answer shape — prose, a list, an
  /// artifact card, then the plan-check failure — so every part of the
  /// thread is reachable on device. The pause is there because an answer
  /// that lands in the same frame as the question reads as a canned one.
  /// What you last asked for, so Retry and Edit have something to work
  /// from. Never written to storage — a private thread must leave nothing.
  String? lastAsk;

  void sendMessage(String text) {
    final String body = text.trim();
    if (body.isEmpty) return;
    lastAsk = body;
    final String stamp = DateTime.now().microsecondsSinceEpoch.toString();
    messages = <ChatMessage>[
      ...messages,
      ChatMessage(id: 'you-$stamp', author: MessageAuthor.you, body: body),
    ];
    thinking = true;
    _changed();

    // The answer comes from the engine. Private chat is passed through so
    // a server can be told not to retain it, on top of this client never
    // writing it down.
    _reply?.ignore();
    _reply = () async {
      try {
        final List<ChatMessage> answer = await _repo.send(
          body,
          private: privateChat,
          avatarId: activeAvatarId,
        );
        messages = <ChatMessage>[...messages, ...answer];
        lastError = null;
      } on ShiftApiException catch (error) {
        lastError = error;
        messages = <ChatMessage>[
          ...messages,
          ChatMessage(
            id: 'error-$stamp',
            author: MessageAuthor.shift,
            body: error.message,
            failure: FailureInfo(
              sentence: 'That did not reach the server.',
              reassurance: error.retryable
                  ? 'Nothing was charged. The next try may well work.'
                  : 'Nothing was charged.',
              details: error.status == null
                  ? error.message
                  : '${error.status} · ${error.message}',
            ),
          ),
        ];
      }
      thinking = false;
      _changed();
    }();
  }

  /// Rewrites what is in the composer into a fuller brief.
  Future<String> polishPrompt(String text) async {
    try {
      final String out = await _repo.polish(text);
      lastError = null;
      return out;
    } on ShiftApiException catch (error) {
      lastError = error;
      return text;
    }
  }

  void clearThread() {
    _reply?.ignore();
    thinking = false;
    messages = <ChatMessage>[];
    lastAsk = null;
    _changed();
  }

  // Persistence ---------------------------------------------------------
  void _changed() {
    notifyListeners();
    _scheduleWrite();
  }

  void _scheduleWrite() {
    _writeTimer?.cancel();
    _writeTimer = Timer(const Duration(milliseconds: 400), _write);
  }

  Future<void> _write() async {
    final Map<String, String> unlocked = <String, String>{
      for (final Trophy t in trophies)
        if (t.earnedOn != null) t.id: t.earnedOn!.toIso8601String(),
    };
    final Map<String, dynamic> blob = <String, dynamic>{
      'v': _blobVersion,
      'theme': themeId.name,
      'disabledFeatures':
          _disabled.map((ShiftFeature f) => f.name).toList(growable: false),
      'surface': surface.name,
      'mode': mode.name,
      'signedIn': signedIn,
      'account': creator.email,
      'agentScope': agentScope,
      'jobScope': jobScope,
      'standings': standings.map((StandingRow r) => r.toJson()).toList(),
      'trophies': unlocked,
      'vault': vault.map((VaultItem v) => v.toJson()).toList(),
      'ecoVault': ecoVault.map((VaultItem v) => v.toJson()).toList(),
      'notes': notes.map((Note n) => n.toJson()).toList(),
    };
    await _prefs.setString(StoreKeys.app, jsonEncode(blob));
  }

  static List<T> _listOr<T>(
    Object? raw,
    T Function(Map<String, dynamic>) parse,
    List<T> fallback,
  ) {
    if (raw is! List || raw.isEmpty) return List<T>.of(fallback);
    try {
      return raw
          .map((Object? e) => parse(e! as Map<String, dynamic>))
          .toList(growable: true);
    } on Object {
      return List<T>.of(fallback);
    }
  }

  @override
  void dispose() {
    _reply?.ignore();
    _writeTimer?.cancel();
    _repo.dispose();
    super.dispose();
  }
}

/// Reaches the store from anywhere below it without a state package.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope(
      {required AppState super.notifier, required super.child, super.key});

  static AppState of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget');
    return scope!.notifier!;
  }

  /// Reads the store without subscribing — for callbacks.
  static AppState read(BuildContext context) {
    final AppScope? scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget');
    return scope!.notifier!;
  }
}
