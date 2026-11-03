import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/alert.dart';

enum _ChatAction { delete }

/// What can be done with a saved chat: the "…" on its row in Recents and
/// over the open chat. Deleting used to be a long press on the row, with
/// nothing to say it was there, and no way at all with a mouse.
Future<void> showChatActions(BuildContext context, ChatThread t) async {
  final _ChatAction? picked = await showShiftActions<_ChatAction>(
    context,
    title: t.title,
    actions: const <ShiftSheetAction<_ChatAction>>[
      ShiftSheetAction<_ChatAction>(
        'Delete chat',
        value: _ChatAction.delete,
        destructive: true,
      ),
    ],
  );
  if (!context.mounted) return;
  switch (picked) {
    case _ChatAction.delete:
      await confirmDeleteChat(context, t);
    case null:
      break;
  }
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
