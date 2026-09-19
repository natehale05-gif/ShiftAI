import 'package:flutter/material.dart';

import '../../app/shell.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/common.dart';

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
              child: ListView(
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: <Widget>[
                              Text(
                                'Notes',
                                style: ShiftType.subheading(c.text)
                                    .copyWith(fontSize: 24),
                              ),
                              const SizedBox(width: Space.x3),
                              Text(
                                count == 1 ? '1 note' : '$count notes',
                                style: ShiftType.bodySm(c.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: Space.x4),
                          const EngineBanner(),
                          if (state.notes.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: Space.x6),
                              child: Text(
                                'Nothing written down yet.',
                                style: ShiftType.body(c.textMuted),
                              ),
                            )
                          else
                            ...state.notes.map(
                              (Note note) => _NoteRow(
                                note: note,
                                onOpen: () => _openNote(context, note),
                                onDelete: () => _deleteNote(context, note),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PillComposer(
              hint: 'Write a note',
              onSend: (String text) async {
                final ScaffoldMessengerState bar =
                    ScaffoldMessenger.of(context);
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
              },
            ),
          ],
        ),
        Positioned(
          right: Space.x6,
          bottom: 104,
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
            tooltip: 'New note',
            child: const Icon(Icons.add_rounded, size: 26),
          ),
        ),
      ],
    );
  }
}

/// Deleting asks first — the other two lists do, and a note has no undo.
Future<void> _deleteNote(BuildContext context, Note note) async {
  final AppState state = AppScope.read(context);
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      final ShiftColors c = ShiftColors.of(context);
      return AlertDialog(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: Text('Delete this note?', style: ShiftType.subheading(c.text)),
        content: Text(
          '\u201c${note.title}\u201d goes for good.',
          style: ShiftType.bodySm(c.textMuted),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.danger,
              foregroundColor: c.onStatus,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      );
    },
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

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.only(top: Space.x2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(note.title, style: ShiftType.bodyStrong(c.text)),
                      const SizedBox(height: Space.x1),
                      Text(note.snippet, style: ShiftType.body(c.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x4),
                IconButton(
                  tooltip: 'Delete this note',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: c.accent,
                  ),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
              ],
            ),
            const SizedBox(height: Space.x3),
            Divider(height: 1, color: c.border),
          ],
        ),
      ),
    );
  }
}

/// Tapping a note — or the + — opens it for editing. Saving writes back
/// through the same store everything else uses.
Future<void> _openNote(BuildContext context, Note note) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ShiftColors.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radii.lg),
    ),
    builder: (BuildContext context) => _NoteEditor(note: note),
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

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final AppState state = AppScope.read(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (BuildContext context, ScrollController scroll) {
          return Column(
            children: <Widget>[
              const SizedBox(height: Space.x3),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderStrong,
                  borderRadius: Radii.pillAll,
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(
                    Space.x5,
                    Space.x4,
                    Space.x5,
                    Space.x5,
                  ),
                  children: <Widget>[
                    TextField(
                      controller: _title,
                      autofocus: widget.note.body.isEmpty,
                      style: ShiftType.subheading(c.text),
                      decoration: InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Title',
                        hintStyle: ShiftType.subheading(c.textMuted),
                      ),
                    ),
                    Divider(color: c.border),
                    TextField(
                      controller: _body,
                      minLines: 8,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.x5,
                  0,
                  Space.x5,
                  Space.x5,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // A note opened from + and left untouched should
                          // not stay behind as an empty row.
                          if (widget.note.body.isEmpty &&
                              _body.text.trim().isEmpty &&
                              _title.text.trim().isEmpty) {
                            state.deleteNote(widget.note.id);
                          }
                          Navigator.of(context).pop();
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final NavigatorState nav = Navigator.of(context);
                          final ScaffoldMessengerState bar =
                              ScaffoldMessenger.of(context);
                          final bool took = await state.saveNote(
                            widget.note.id,
                            title: _title.text,
                            body: _body.text,
                          );
                          nav.pop();
                          if (!took) {
                            bar.showSnackBar(
                              SnackBar(
                                content: Text(
                                  state.lastError?.message ??
                                      'Could not save it.',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('SAVE'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
