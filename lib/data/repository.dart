import '../features/settings/connectors.dart';
import '../models/models.dart';

/// Everything the client needs to draw itself, fetched in one go.
///
/// The app reads a snapshot at startup and then mutates through the
/// repository. Keeping it one object means a backend can answer with one
/// round trip if it wants to, and the client does not care either way.
class ShiftSnapshot {
  const ShiftSnapshot({
    required this.creator,
    required this.standings,
    required this.trophies,
    required this.vault,
    required this.ecoVault,
    required this.notes,
    required this.agentRuns,
    required this.jobs,
    required this.designs,
    required this.connectors,
    required this.weekPool,
    required this.payoutLine,
    required this.avatars,
    this.league,
    this.boards,
    this.models = const <ChatModel>[],
  });

  /// The AIs the server has connected, from `GET /v1/models`. Empty for an
  /// engine that does not list them, and then it picks who answers.
  final List<ChatModel> models;

  /// The Suite's weekly boards, when the engine serves `/v1/boards`. Null
  /// before it does, and in the seeded demo, which keeps its own board.
  final SuiteBoards? boards;

  final Creator creator;
  final List<StandingRow> standings;
  final List<Trophy> trophies;
  final List<VaultItem> vault;

  /// EcoVault: everyone's published work, the viewer's own included. Each
  /// row carries who made it and whether this viewer has hearted it.
  final List<VaultItem> ecoVault;
  final List<Note> notes;
  final List<AgentRun> agentRuns;
  final List<JobRow> jobs;
  final List<DesignDoc> designs;
  final List<Connector> connectors;
  final int weekPool;
  final String payoutLine;

  /// Every avatar this creator has trained, personal one included.
  final List<Avatar> avatars;

  /// This account's local league placement, or null before it has shared a
  /// location. Never falls back to the global board — see `League.fromJson`.
  final League? league;
}

/// An empty snapshot: what a brand new account looks like before it has
/// made anything, and what a failed load falls back to once a backend is
/// configured. The alternative — falling back to the seeded catalogue —
/// shows one person another person's vault, trophies and earnings as
/// though they were their own.
ShiftSnapshot emptySnapshot() => const ShiftSnapshot(
      creator: Creator(handle: '', name: '', email: '', initials: ''),
      standings: <StandingRow>[],
      trophies: <Trophy>[],
      vault: <VaultItem>[],
      ecoVault: <VaultItem>[],
      notes: <Note>[],
      agentRuns: <AgentRun>[],
      jobs: <JobRow>[],
      designs: <DesignDoc>[],
      connectors: <Connector>[],
      weekPool: 0,
      payoutLine: '',
      avatars: <Avatar>[],
    );

/// What a backend has to be able to do. Every screen in the app reads and
/// writes through this and nothing else, so swapping the engine underneath
/// is one class rather than a sweep through the UI.
///
/// The methods are deliberately coarse. A chattier interface would push
/// the server's shape into the widgets, which is the thing this exists to
/// prevent.
abstract interface class ShiftRepository {
  /// Everything needed to draw the app. Called once on start, and again on
  /// an explicit refresh.
  Future<ShiftSnapshot> load();

  /// Ask for something. The answer is whatever the engine sends back —
  /// one or more messages, in order. [avatarId] names one of this
  /// creator's own avatars to generate as; omitted, the engine answers in
  /// whatever voice it answers in by default.
  ///
  /// [model] names which AI answers; null lets the server pick. [history]
  /// is the whole conversation before [prompt], so the model that answers
  /// reads everything said so far, including other models' replies.
  Future<List<ChatMessage>> send(
    String prompt, {
    bool private = false,
    String? avatarId,
    String? model,
    List<ChatTurn> history = const <ChatTurn>[],
  });

  /// Rewrite a rough ask into a fuller brief. Returning the text unchanged
  /// is a valid answer for a backend that does not do this.
  Future<String> polish(String prompt);

  // Profile ----------------------------------------------------------------
  /// Changes the signed-in creator's username. Whether it is taken is the
  /// server's call, reported back as [ShiftApiErrorKind.badRequest].
  Future<Creator> updateHandle(String handle);

  // Avatars ----------------------------------------------------------------
  /// This creator's avatars, on their own: what the gallery re-reads while
  /// one is training, without reloading everything else.
  Future<List<Avatar>> avatars();

  /// Starts training a new avatar from an already-[upload]ed photo. Comes
  /// back `training` — HeyGen does not render synchronously, so [avatars]
  /// is what learns it finished.
  ///
  /// Only ever called after the person has confirmed the photo is of them
  /// and agreed to it being used for their likeness; the request says so,
  /// so the server can record it where the Suite records likeness consent.
  Future<Avatar> createAvatar({required String uploadId, required String name});

  /// Makes this the avatar shown as the profile picture and on the
  /// leaderboard. The server holds "exactly one personal avatar" as an
  /// invariant; the client only ever asks for a specific one.
  Future<Avatar> makeAvatarPersonal(String id);

  Future<void> deleteAvatar(String id);

  // Local league -----------------------------------------------------------
  /// Tells the engine where this device is, coarse enough for a metro area.
  /// Answers with the resulting placement, or null if the engine has not
  /// placed this account yet — a first call may need a moment to land in a
  /// cohort.
  Future<League?> shareLocation({required double lat, required double lng});

  // Vault ----------------------------------------------------------------
  /// Hearts a piece in EcoVault, which is what puts it in the person's own
  /// vault. Saving someone else's work copies nothing and changes nothing
  /// about their piece — it is a bookmark, and it is the viewer's.
  Future<VaultItem> saveVaultItem(String id);
  Future<VaultItem> unsaveVaultItem(String id);

  Future<VaultItem> renameVaultItem(String id, String title);
  Future<VaultItem> publishVaultItem(String id);
  Future<void> deleteVaultItem(String id);

  // Notes ----------------------------------------------------------------
  Future<Note> createNote({required String title, required String body});
  Future<Note> saveNote(
    String id, {
    required String title,
    required String body,
  });
  Future<void> deleteNote(String id);

  // Agents ---------------------------------------------------------------
  /// Hands a task to an agent working in [scope]. The row that comes back
  /// is what the Agents tab shows while it runs.
  Future<AgentRun> startRun(String prompt, {required String scope});

  /// Queues a job against the folder [scope].
  Future<JobRow> startJob(String prompt, {required String scope});

  /// Starts an existing run again from the top, clearing whatever it
  /// finished with last time.
  Future<AgentRun> rerunRun(String id);

  // Designs --------------------------------------------------------------
  Future<DesignDoc> duplicateDesign(String id);
  Future<void> deleteDesign(String id);

  /// Uploads an attachment and returns the id the backend filed it under.
  Future<String> upload({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  });

  /// Release anything held open. Called when the app shuts down.
  void dispose() {}
}

/// What went wrong, in terms the UI can act on rather than a raw status
/// code it would have to interpret at every call site.
class ShiftApiException implements Exception {
  const ShiftApiException(this.kind, this.message, {this.status});

  final ShiftApiErrorKind kind;
  final String message;
  final int? status;

  /// True where trying the same thing again could plausibly work.
  bool get retryable =>
      kind == ShiftApiErrorKind.offline ||
      kind == ShiftApiErrorKind.timeout ||
      kind == ShiftApiErrorKind.server;

  @override
  String toString() => 'ShiftApiException(${kind.name}, $message)';
}

enum ShiftApiErrorKind {
  /// No route to the server at all.
  offline,

  /// The server took too long.
  timeout,

  /// Signed out, or the token expired.
  unauthorised,

  /// Signed in, but not allowed to do this.
  forbidden,

  /// No such thing.
  notFound,

  /// The request was wrong.
  badRequest,

  /// The server broke.
  server,

  /// The body was not what the contract says.
  malformed,
}
