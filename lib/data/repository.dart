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
  });

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
  /// one or more messages, in order.
  Future<List<ChatMessage>> send(String prompt, {bool private = false});

  /// Rewrite a rough ask into a fuller brief. Returning the text unchanged
  /// is a valid answer for a backend that does not do this.
  Future<String> polish(String prompt);

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
