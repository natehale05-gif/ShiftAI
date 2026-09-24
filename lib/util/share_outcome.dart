/// What happened when something was shared, so the screen can say so.
enum ShareOutcome {
  /// The system share sheet took it.
  shared,

  /// There is no share sheet here; the text is on the clipboard instead.
  copied,

  /// The sheet was closed without sharing.
  dismissed,
}
