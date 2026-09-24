import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/shell.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../util/format.dart';
import '../../widgets/common.dart';
import '../../widgets/alert.dart';

/// A flat list. A note is a title and what it says — nothing else earns a
/// place here.
class NotesSurface extends StatelessWidget {
  const NotesSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final int count = state.notes.length;

    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            Expanded(
              child: PullToRefresh(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    Space.x5,
                    Space.x5,
                    Space.x5,
                    Space.x5,
                  ),
                  children: <Widget>[
                    Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: kContentWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text('Notes', style: ShiftType.largeTitle(c.text)),
                            const SizedBox(height: 2),
                            Text(
                              count == 1 ? '1 note' : '$count notes',
                              style: ShiftType.copy(c.textMuted, size: 15),
                            ),
                            const SizedBox(height: Space.x4),
                            const EngineBanner(),
                            if (state.notes.isEmpty)
                              EmptyState(
                                icon: Icons.edit_note_rounded,
                                title: 'No notes yet',
                                message: 'Write one down in the bar below, '
                                    'or start a blank page.',
                                actionLabel: 'New note',
                                onAction: () async {
                                  final Note? note = await state.addNote();
                                  if (note != null && context.mounted) {
                                    await _openNote(context, note);
                                  }
                                },
                              )
                            else
                              GroupedList(
                                children: state.notes
                                    .map(
                                      (Note note) => _NoteRow(
                                        note: note,
                                        onOpen: () => _openNote(context, note),
                                        onDelete: () =>
                                            _deleteNote(context, note),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PillComposer(
              hint: 'Write a note',
              onSend: (String text) {
                // The bar clears straight away and the save reports itself
                // in a snack bar, exactly as it did while this callback
                // could not answer at all.
                final ScaffoldMessengerState bar =
                    ScaffoldMessenger.of(context);
                unawaited(() async {
                  final Note? note = await state.addNote(
                    title: text.split('\n').first,
                    body: text,
                  );
                  bar.showSnackBar(
                    SnackBar(
                      content: Text(
                        note == null
                            ? state.lastError?.message ?? 'Could not save it.'
                            : 'Saved “${note.title}”',
                      ),
                    ),
                  );
                }());
                return true;
              },
            ),
          ],
        ),
        Positioned(
          right: Space.x6,
          // Above the composer, which rises by the bottom inset.
          bottom: 104 + MediaQuery.paddingOf(context).bottom,
          child: FloatingActionButton(
            onPressed: () async {
              final Note? note = await state.addNote();
              if (note != null && context.mounted) {
                await _openNote(context, note);
              }
            },
            backgroundColor: c.accent,
            foregroundColor: c.onAccent,
            elevation: 0,
            // A round compose button, the way Notes has one, rather than
            // Material's squircle with a plus in it.
            shape: const CircleBorder(),
            tooltip: 'New note',
            child: const Icon(Icons.edit_square, size: 24),
          ),
        ),
      ],
    );
  }
}

/// Deleting asks first — the other two lists do, and a note has no undo.
Future<void> _deleteNote(BuildContext context, Note note) async {
  final AppState state = AppScope.read(context);
  final bool? yes = await showShiftAlert<bool>(
    context,
    title: 'Delete this note?',
    message: '\u201c${note.title}\u201d goes for good.',
    actions: const <ShiftAlertAction<bool>>[
      ShiftAlertAction<bool>('Cancel', value: false, isDefault: true),
      ShiftAlertAction<bool>('Delete', value: true, destructive: true),
    ],
  );
  if (!(yes ?? false) || !context.mounted) return;
  final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
  if (!await state.deleteNote(note.id)) {
    bar.showSnackBar(
      SnackBar(
        content: Text(state.lastError?.message ?? 'Could not delete it.'),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.note,
    required this.onOpen,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);

    // Swipe left to delete, as a list row does on a phone; the icon stays
    // for a pointer, muted, so it is there without shouting on every row.
    // Both go through the same confirmation, and a swipe that is declined
    // springs back.
    return Dismissible(
      key: ValueKey<String>('note-${note.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        color: c.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.x5),
        child: Icon(Icons.delete_outline_rounded, color: c.onStatus),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.x4,
            Space.x3,
            Space.x1,
            Space.x3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShiftType.copy(c.text, size: 16, weight: 600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note.snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ShiftType.copy(
                        c.textMuted,
                        size: 15,
                        lineHeight: 21,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete this note',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: c.textMuted.withValues(alpha: 0.7),
                ),
                style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tapping a note, or the compose button, opens it full screen. Nothing
/// has to be saved: what is typed is written back a moment after you
/// stop, and again on the way out.
///
/// It used to be a bottom sheet with Cancel and Save, and Cancel threw the
/// changes away. Apple's Notes has no Save button at all, and a note lost
/// to a mistaken tap is the one failure a notes app cannot have.
Future<void> _openNote(BuildContext context, Note note) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => _NoteEditor(note: note),
    ),
  );
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.note});

  final Note note;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _title = TextEditingController(
      text: widget.note.title == 'Untitled' ? '' : widget.note.title);
  late final TextEditingController _body =
      TextEditingController(text: widget.note.body);
  final FocusNode _bodyFocus = FocusNode();
  final FocusNode _titleFocus = FocusNode();

  /// How long after the last keystroke the note is written.
  static const Duration _settle = Duration(milliseconds: 700);

  Timer? _pending;
  late String _savedTitle = _title.text;
  late String _savedBody = _body.text;
  bool _reportedFailure = false;

  // Held, not looked up: dispose writes the note back, and by then the
  // tree they would be looked up in is gone.
  late AppState _state;
  late ScaffoldMessengerState _messenger;

  bool get _dirty => _title.text != _savedTitle || _body.text != _savedBody;
  bool get _blank => _title.text.trim().isEmpty && _body.text.trim().isEmpty;
  bool get _editing => _bodyFocus.hasFocus || _titleFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _body.addListener(_changed);
    _bodyFocus.addListener(() => setState(() {}));
    _titleFocus.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppScope.read(context);
    _messenger = ScaffoldMessenger.of(context);
  }

  void _changed() {
    if (!_dirty) return;
    _pending?.cancel();
    _pending = Timer(_settle, _save);
  }

  Future<void> _save() async {
    _pending?.cancel();
    _pending = null;
    if (!_dirty || _blank) return;
    final String title = _title.text;
    final String body = _body.text;
    final bool took =
        await _state.saveNote(widget.note.id, title: title, body: body);
    if (took) {
      _savedTitle = title;
      _savedBody = body;
      _reportedFailure = false;
    } else if (!_reportedFailure) {
      // Once, not on every keystroke. The text stays on screen and the
      // next pause tries again.
      _reportedFailure = true;
      _messenger.showSnackBar(
        SnackBar(
          content: Text(
            _state.lastError?.message ??
                'Could not save this note. It is still here; keep typing '
                    'and it will try again.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pending?.cancel();
    // A note opened from the compose button and left empty should not
    // stay behind as a blank row. Anything else is written on the way out.
    //
    // After the frame, not here: dispose runs while the tree is being torn
    // down, and a write here notifies listeners mid-teardown, which threw
    // "setState() or markNeedsBuild() called when widget tree was locked".
    final String id = widget.note.id;
    final String title = _title.text;
    final String body = _body.text;
    final AppState state = _state;
    if (_blank) {
      Future<void>.microtask(() => state.deleteNote(id));
    } else if (_dirty) {
      Future<void>.microtask(
        () => state.saveNote(id, title: title, body: body),
      );
    }
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final NavigatorState nav = Navigator.of(context);
    final bool? yes = await showShiftAlert<bool>(
      context,
      title: 'Delete this note?',
      message: 'It goes for good.',
      actions: const <ShiftAlertAction<bool>>[
        ShiftAlertAction<bool>('Cancel', value: false, isDefault: true),
        ShiftAlertAction<bool>('Delete', value: true, destructive: true),
      ],
    );
    if (!(yes ?? false)) return;
    _pending?.cancel();
    // Blank the fields so dispose does not write the note back.
    _title.clear();
    _body.clear();
    await _state.deleteNote(widget.note.id);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 52,
              child: Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.chevron_left_rounded,
                        size: 28, color: c.accent),
                    label: Text(
                      'Notes',
                      style: ShiftType.copy(c.accent, size: 17, weight: 500),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(left: 4, right: 12),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Delete this note',
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 21, color: c.accent),
                  ),
                  // Done puts the keyboard away, as it does in Notes. The
                  // note is already saved either way.
                  if (_editing)
                    TextButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        _save();
                      },
                      child: Text(
                        'Done',
                        style: ShiftType.copy(c.accent, size: 17, weight: 600),
                      ),
                    ),
                  const SizedBox(width: Space.x2),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                // A tap in the empty space under the text carries on
                // writing, rather than doing nothing.
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (!_editing) _bodyFocus.requestFocus();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.x5,
                    Space.x2,
                    Space.x5,
                    Space.x7,
                  ),
                  children: <Widget>[
                    Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: kContentWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              Fmt.dateTime(widget.note.editedAt),
                              textAlign: TextAlign.center,
                              style: ShiftType.caption(c.textMuted),
                            ),
                            const SizedBox(height: Space.x3),
                            TextField(
                              controller: _title,
                              focusNode: _titleFocus,
                              autofocus: widget.note.body.isEmpty &&
                                  _title.text.isEmpty,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _bodyFocus.requestFocus(),
                              style: ShiftType.title1(c.text),
                              decoration: InputDecoration(
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Title',
                                hintStyle: ShiftType.title1(c.textMuted),
                              ),
                            ),
                            const SizedBox(height: Space.x2),
                            TextField(
                              controller: _body,
                              focusNode: _bodyFocus,
                              minLines: 12,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              style: ShiftType.body(c.text),
                              decoration: InputDecoration(
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Write it down',
                                hintStyle: ShiftType.body(c.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
