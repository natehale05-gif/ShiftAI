import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../util/file_pick.dart';
import '../../widgets/alert.dart';
import '../../widgets/common.dart';
import '../chat/chat_actions.dart';

/// One project: its instructions, the files and notes its chats are
/// given, and its chats. "I need projects where I can add multiple chats
/// and other resources to be used together" (3 Nov).
class ProjectSurface extends StatelessWidget {
  const ProjectSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final Project? p = state.openProject;
    if (p == null) {
      return const EmptyState(
        icon: Icons.folder_outlined,
        title: 'No project open',
        message: 'Pick one under Projects in the sidebar, or start a new one.',
      );
    }
    final List<ChatThread> chats = state.threadsIn(p.id);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.x4,
        Space.x4,
        Space.x4,
        Space.x8,
      ),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.folder_outlined, color: c.accent, size: 26),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(p.name, style: ShiftType.title1(c.text)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Options for this project',
                      onPressed: () => _projectActions(context, p),
                      icon: Icon(Icons.more_horiz_rounded, color: c.textMuted),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.x4),
                FilledButton.icon(
                  onPressed: () {
                    // A notice from this screen ("Uploading…") would sit
                    // over the composer the new chat opens on.
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    state.newChatIn(p.id);
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New chat in this project'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.onAccent,
                    minimumSize: const Size.fromHeight(46),
                    shape: const RoundedRectangleBorder(
                      borderRadius: Radii.pillAll,
                    ),
                  ),
                ),
                _Heading(
                  'Instructions',
                  action: 'Edit',
                  onAction: () => _editInstructions(context, p),
                ),
                ShiftCard(
                  child: Text(
                    p.instructions.isEmpty
                        ? 'What every chat in this project should know: who '
                            'it is for, the tone, what to keep in mind.'
                        : p.instructions,
                    style: ShiftType.bodySm(
                      p.instructions.isEmpty ? c.textMuted : c.text,
                    ),
                  ),
                ),
                _Heading(
                  'Files and notes',
                  // Upload opens the file dialog from the tap itself: Safari
                  // only opens one straight from a tap, not after a sheet
                  // has closed in between.
                  extra: 'Upload',
                  onExtra: () => _uploadFiles(context, p),
                  action: 'Add',
                  onAction: () => _addResource(context, p),
                ),
                if (p.resources.isEmpty)
                  const _Hint(
                    'Add pictures and videos from your vault, notes, or '
                    'files. Every chat in this project is given them.',
                  )
                else
                  GroupedList(
                    dividerInset: 52,
                    children: <Widget>[
                      for (final ProjectResource r in p.resources)
                        _Row(
                          icon: switch (r.kind) {
                            ProjectResourceKind.vault =>
                              Icons.grid_view_rounded,
                            ProjectResourceKind.note =>
                              Icons.sticky_note_2_outlined,
                            ProjectResourceKind.file =>
                              Icons.description_outlined,
                          },
                          title: r.name,
                          subtitle: _resourceLine(state, r),
                          trailing: IconButton(
                            tooltip: 'Remove ${r.name} from this project',
                            onPressed: () =>
                                state.removeProjectResource(p.id, r.key),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: c.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                const _Heading('Chats'),
                if (chats.isEmpty)
                  const _Hint(
                    'No chats yet. Start one above, or move one here from '
                    'its "…" menu.',
                  )
                else
                  GroupedList(
                    dividerInset: 52,
                    children: <Widget>[
                      for (final ChatThread t in chats)
                        _Row(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: t.title,
                          subtitle: _when(t.updatedAt),
                          onTap: () => state.openThread(t.id),
                          trailing: IconButton(
                            tooltip: 'Options for this chat',
                            onPressed: () => showChatActions(context, t),
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              size: 18,
                              color: c.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _resourceLine(AppState state, ProjectResource r) =>
      switch (r.kind) {
        ProjectResourceKind.vault =>
          state.vault.any((VaultItem v) => v.id == r.ref)
              ? 'From your vault'
              : 'No longer in your vault',
        ProjectResourceKind.note =>
          state.notes.any((Note n) => n.id == r.ref) ? 'Note' : 'Note deleted',
        ProjectResourceKind.file =>
          r.sizeBytes == null ? 'File' : 'File · ${_size(r.sizeBytes!)}',
      };

  static String _size(int b) => b >= 1 << 20
      ? '${(b / (1 << 20)).toStringAsFixed(1)} MB'
      : b >= 1 << 10
          ? '${(b / (1 << 10)).round()} KB'
          : '$b B';

  static String _when(DateTime t) {
    final Duration ago = DateTime.now().difference(t);
    if (ago.inMinutes < 1) return 'Just now';
    if (ago.inHours < 1) return '${ago.inMinutes} min ago';
    if (ago.inDays < 1) return '${ago.inHours} h ago';
    if (ago.inDays < 7) return '${ago.inDays} d ago';
    return '${t.day}/${t.month}/${t.year}';
  }
}

class _Heading extends StatelessWidget {
  const _Heading(
    this.text, {
    this.action,
    this.onAction,
    this.extra,
    this.onExtra,
  });

  final String text;
  final String? action;
  final VoidCallback? onAction;
  final String? extra;
  final VoidCallback? onExtra;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.x1, Space.x6, 0, Space.x2),
      child: Row(
        children: <Widget>[
          Expanded(child: Eyebrow(text)),
          if (extra != null)
            TextButton(
              onPressed: onExtra,
              child: Text(extra!, style: ShiftType.callout(c.accent)),
            ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!, style: ShiftType.callout(c.accent)),
            ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.x1),
      child: Text(text, style: ShiftType.bodySm(c.textMuted)),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(Space.x4, Space.x3, Space.x2, Space.x3),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: c.textMuted),
            const SizedBox(width: Space.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ShiftType.body(c.text),
                  ),
                  Text(subtitle, style: ShiftType.caption(c.textMuted)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// "New project": its name, then its screen.
Future<void> startNewProject(BuildContext context) async {
  final AppState state = AppScope.read(context);
  final String? name = await showShiftAlert<String>(
    context,
    title: 'New project',
    message: 'Keep chats together, with instructions and files they all '
        'use.',
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
  state.createProject(name);
}

enum _ProjectAction { rename, delete }

Future<void> _projectActions(BuildContext context, Project p) async {
  final AppState state = AppScope.read(context);
  final _ProjectAction? picked = await showShiftActions<_ProjectAction>(
    context,
    title: p.name,
    actions: const <ShiftSheetAction<_ProjectAction>>[
      ShiftSheetAction<_ProjectAction>('Rename project',
          value: _ProjectAction.rename),
      ShiftSheetAction<_ProjectAction>(
        'Delete project',
        value: _ProjectAction.delete,
        destructive: true,
      ),
    ],
  );
  if (!context.mounted || picked == null) return;
  switch (picked) {
    case _ProjectAction.rename:
      final String? name = await showShiftAlert<String>(
        context,
        title: 'Rename project',
        field: ShiftAlertField(initial: p.name, placeholder: 'Name'),
        actions: <ShiftAlertAction<String>>[
          const ShiftAlertAction<String>('Cancel'),
          ShiftAlertAction<String>(
            'Save',
            isDefault: true,
            valueOf: (String typed) => typed,
            enabled: (String typed) => typed.trim().isNotEmpty,
          ),
        ],
      );
      if (name != null) state.renameProject(p.id, name);
    case _ProjectAction.delete:
      final int chats = state.threadsIn(p.id).length;
      final bool? yes = await showShiftAlert<bool>(
        context,
        title: 'Delete this project?',
        message: chats == 0
            ? '“${p.name}” and its instructions go. Nothing in '
                'your vault or notes is deleted.'
            : '“${p.name}” and its instructions go. Its '
                '${chats == 1 ? 'chat is' : '$chats chats are'} kept, in '
                'Recents. Nothing in your vault or notes is deleted.',
        actions: const <ShiftAlertAction<bool>>[
          ShiftAlertAction<bool>('Cancel', value: false, isDefault: true),
          ShiftAlertAction<bool>('Delete', value: true, destructive: true),
        ],
      );
      if (yes ?? false) state.deleteProject(p.id);
  }
}

Future<void> _editInstructions(BuildContext context, Project p) async {
  final AppState state = AppScope.read(context);
  final String? text = await showShiftAlert<String>(
    context,
    title: 'Instructions',
    message: 'Every chat in “${p.name}” is told this first.',
    field: ShiftAlertField(
      initial: p.instructions,
      placeholder: 'Who it is for, the tone, what to keep in mind',
      minLines: 4,
      maxLines: 10,
    ),
    actions: <ShiftAlertAction<String>>[
      const ShiftAlertAction<String>('Cancel'),
      ShiftAlertAction<String>(
        'Save',
        isDefault: true,
        valueOf: (String typed) => typed,
      ),
    ],
  );
  if (text != null) state.setProjectInstructions(p.id, text);
}

enum _AddFrom { vault, note }

Future<void> _addResource(BuildContext context, Project p) async {
  final _AddFrom? from = await showShiftActions<_AddFrom>(
    context,
    title: 'Add to “${p.name}”',
    actions: const <ShiftSheetAction<_AddFrom>>[
      ShiftSheetAction<_AddFrom>('From your vault', value: _AddFrom.vault),
      ShiftSheetAction<_AddFrom>('A note', value: _AddFrom.note),
    ],
  );
  if (!context.mounted || from == null) return;
  switch (from) {
    case _AddFrom.vault:
      await _pickFromVault(context, p);
    case _AddFrom.note:
      await _pickNote(context, p);
  }
}

Future<void> _pickFromVault(BuildContext context, Project p) async {
  final AppState state = AppScope.read(context);
  final List<VaultItem> mine =
      state.vault.where((VaultItem v) => v.mine).toList(growable: false);
  if (mine.isEmpty) {
    _say(context, 'Your vault is empty. What you make is kept there.');
    return;
  }
  final VaultItem? picked = await _pickSheet<VaultItem>(
    context,
    title: 'From your vault',
    items: mine,
    label: (VaultItem v) => v.title,
    detail: (VaultItem v) => v.mediaType.label,
    leading: (VaultItem v) => SizedBox.square(
      dimension: 40,
      child: ClipRRect(
        borderRadius: Radii.smAll,
        child: MediaThumbnail(
          seed: v.id,
          thumbnailUrl: v.thumbnailUrl,
          mediaType: v.mediaType,
          video: v.mediaType == MediaType.video,
        ),
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  final bool added = state.addProjectResource(
    p.id,
    ProjectResource(
      kind: ProjectResourceKind.vault,
      ref: picked.id,
      name: picked.title,
    ),
  );
  if (!added) _say(context, '“${picked.title}” is already in it.');
}

Future<void> _pickNote(BuildContext context, Project p) async {
  final AppState state = AppScope.read(context);
  if (state.notes.isEmpty) {
    _say(context, 'You have no notes yet. Write one in Notes.');
    return;
  }
  final Note? picked = await _pickSheet<Note>(
    context,
    title: 'A note',
    items: state.notes,
    label: (Note n) => n.title.trim().isEmpty ? 'Untitled note' : n.title,
    detail: (Note n) => n.body.trim().split('\n').first,
    leading: (Note n) => Icon(
      Icons.sticky_note_2_outlined,
      color: ShiftColors.of(context).textMuted,
    ),
  );
  if (picked == null || !context.mounted) return;
  final bool added = state.addProjectResource(
    p.id,
    ProjectResource(
      kind: ProjectResourceKind.note,
      ref: picked.id,
      name: picked.title.trim().isEmpty ? 'Untitled note' : picked.title,
    ),
  );
  if (!added) _say(context, 'That note is already in it.');
}

Future<void> _uploadFiles(BuildContext context, Project p) async {
  final AppState state = AppScope.read(context);
  final List<PickedFile> files = await pickAnyFiles();
  if (files.isEmpty || !context.mounted) return;
  _say(context,
      'Uploading ${files.length == 1 ? files.single.name : '${files.length} files'}…');
  int added = 0;
  for (final PickedFile f in files) {
    final String? refused = await state.uploadToProject(p.id, f);
    if (refused == null) {
      added++;
    } else if (context.mounted) {
      _say(context, '${f.name} was not added: $refused');
    }
  }
  if (added > 0 && context.mounted) {
    _say(context,
        added == 1 ? 'Added ${files.first.name}' : 'Added $added files');
  }
}

Future<T?> _pickSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) label,
  required String Function(T) detail,
  required Widget Function(T) leading,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShiftColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radii.lg),
      ),
      builder: (BuildContext sheet) {
        final ShiftColors c = ShiftColors.of(sheet);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(Space.x5),
                  child: Text(title, style: ShiftType.subheading(c.text)),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final T item in items)
                        ListTile(
                          leading: leading(item),
                          title: Text(
                            label(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ShiftType.body(c.text),
                          ),
                          subtitle: Text(
                            detail(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ShiftType.caption(c.textMuted),
                          ),
                          onTap: () => Navigator.of(sheet).pop(item),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.x3),
              ],
            ),
          ),
        );
      },
    );

/// A short notice, floating, so it never covers the composer.
void _say(BuildContext context, String text) {
  final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
  bar.hideCurrentSnackBar();
  bar.showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}
