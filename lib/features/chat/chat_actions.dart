import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/alert.dart';

enum _ChatAction { toProject, outOfProject, delete }

/// What can be done with a saved chat: the "…" on its row in Recents and
/// over the open chat. Deleting used to be a long press on the row, with
/// nothing to say it was there, and no way at all with a mouse.
Future<void> showChatActions(BuildContext context, ChatThread t) async {
  final AppState state = AppScope.read(context);
  final Project? inProject = state.projectById(t.projectId);
  final _ChatAction? picked = await showShiftActions<_ChatAction>(
    context,
    title: inProject == null ? t.title : '${t.title} · ${inProject.name}',
    actions: <ShiftSheetAction<_ChatAction>>[
      ShiftSheetAction<_ChatAction>(
        inProject == null ? 'Add to project…' : 'Move to another project…',
        value: _ChatAction.toProject,
      ),
      if (inProject != null)
        ShiftSheetAction<_ChatAction>(
          'Remove from \u201c${inProject.name}\u201d',
          value: _ChatAction.outOfProject,
        ),
      const ShiftSheetAction<_ChatAction>(
        'Delete chat',
        value: _ChatAction.delete,
        destructive: true,
      ),
    ],
  );
  if (!context.mounted) return;
  switch (picked) {
    case _ChatAction.toProject:
      await _moveToProject(context, t);
    case _ChatAction.outOfProject:
      state.moveThread(t.id, null);
    case _ChatAction.delete:
      await confirmDeleteChat(context, t);
    case null:
      break;
  }
}

/// Which project [t] goes in: one there is, or a new one.
Future<void> _moveToProject(BuildContext context, ChatThread t) async {
  final AppState state = AppScope.read(context);
  const String fresh = '\u0000new';
  final String? picked = await showShiftActions<String>(
    context,
    title: 'Add \u201c${t.title}\u201d to',
    actions: <ShiftSheetAction<String>>[
      for (final Project p in state.projects)
        if (p.id != t.projectId) ShiftSheetAction<String>(p.name, value: p.id),
      const ShiftSheetAction<String>('New project…', value: fresh),
    ],
  );
  if (!context.mounted || picked == null) return;
  if (picked != fresh) {
    state.moveThread(t.id, picked);
    return;
  }
  final String? name = await showShiftAlert<String>(
    context,
    title: 'New project',
    field: const ShiftAlertField(placeholder: 'Name'),
    actions: <ShiftAlertAction<String>>[
      const ShiftAlertAction<String>('Cancel'),
      ShiftAlertAction<String>(
        'Create',
        isDefault: true,
        valueOf: (String typed) => typed,
        enabled: (String typed) => typed.trim().isNotEmpty,
      ),
    ],
  );
  if (name == null || name.trim().isEmpty) return;
  final Project made = state.createProject(name, open: false);
  state.moveThread(t.id, made.id);
}

/// "Delete this chat?", and if so, it goes: here, on the server, and from
/// every later load.
Future<void> confirmDeleteChat(BuildContext context, ChatThread t) async {
  final AppState state = AppScope.read(context);
  final bool? yes = await showShiftAlert<bool>(
    context,
    title: 'Delete this chat?',
    message: '“${t.title}” goes for good.',
    actions: const <ShiftAlertAction<bool>>[
      ShiftAlertAction<bool>('Cancel', value: false, isDefault: true),
      ShiftAlertAction<bool>('Delete', value: true, destructive: true),
    ],
  );
  if (yes ?? false) state.deleteThread(t.id);
}
