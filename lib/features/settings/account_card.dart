import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/common.dart';
import 'avatar.dart';
import '../../widgets/alert.dart';

/// The account, and the one line that matters about billing: there is no
/// separate plan to buy.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);

    return ShiftCard(
      child: Wrap(
        spacing: Space.x5,
        runSpacing: Space.x4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          ShiftAvatar(
            previewUrl: state.personalAvatar?.previewUrl,
            initials: state.creator.initials,
            size: 48,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(state.creator.name, style: ShiftType.bodyStrong(c.text)),
              Text(state.creator.email, style: ShiftType.bodySm(c.textMuted)),
              // The handle and its pencil are one button, 44 tall. The
              // pencil alone was a 22-point target with no label, so a
              // screen reader announced a nameless button.
              Semantics(
                button: true,
                label: 'Change username, @${state.creator.bareHandle}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => _renameHandle(context),
                  borderRadius: Radii.smAll,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '@${state.creator.bareHandle}',
                          style: ShiftType.bodySm(c.textMuted),
                        ),
                        const SizedBox(width: Space.x2),
                        Icon(Icons.edit, size: 14, color: c.textMuted),
                        const SizedBox(width: Space.x2),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x3,
              vertical: Space.x2,
            ),
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: Radii.pillAll,
            ),
            child: Text(
              'Included with membership',
              style: ShiftType.caption(c.accent),
            ),
          ),
          OutlinedButton(
            onPressed: state.signOut,
            child: Text('Sign out', style: ShiftType.bodySm(c.text)),
          ),
        ],
      ),
    );
  }
}

/// On its own at the very bottom of Settings — the one action here that
/// cannot be undone belongs nowhere near the buttons people actually mean
/// to tap.
class DeleteAccountCard extends StatelessWidget {
  const DeleteAccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);

    return ShiftCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Delete account', style: ShiftType.bodyStrong(c.text)),
                const SizedBox(height: Space.x1),
                Text(
                  'Your vault, your notes, your designs and your place on '
                  'the board go with it. This cannot be undone.',
                  style: ShiftType.caption(c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.x4),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: c.danger,
              side: BorderSide(color: c.danger),
            ),
            onPressed: () => _deleteAccount(context),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// The username that attributes a person's work in EcoVault.
Future<void> _renameHandle(BuildContext context) async {
  final AppState state = AppScope.read(context);
  // The field sits behind a '@' prefix, so it holds the bare handle.
  final String? next = await showShiftAlert<String>(
    context,
    title: 'Change username',
    field: ShiftAlertField(initial: state.creator.bareHandle, prefixText: '@'),
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
  // A typed-in '@' is dropped rather than sent: the engine stores the
  // bare handle, and every screen adds the '@' back when it draws one.
  String trimmed = (next ?? '').trim();
  if (trimmed.startsWith('@')) trimmed = trimmed.substring(1).trim();
  if (trimmed.isEmpty ||
      trimmed.contains(RegExp(r'\s')) ||
      trimmed == state.creator.bareHandle ||
      !context.mounted) {
    return;
  }

  final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
  if (!await state.updateHandle(trimmed)) {
    bar.showSnackBar(
      SnackBar(
        content: Text(state.lastError?.message ?? 'Could not change username.'),
      ),
    );
  }
}

/// Apple requires an app that creates accounts to let people delete them
/// from inside the app (Guideline 5.1.1(v)). Typed confirmation rather
/// than a two-button dialog, because this one does not come back.
Future<void> _deleteAccount(BuildContext context) async {
  final AppState state = AppScope.read(context);
  final bool? sure = await showShiftAlert<bool>(
    context,
    title: 'Delete your account?',
    message: 'Your vault, your notes, your designs and your place on the '
        'board go with it. This cannot be undone and support cannot '
        'restore it.\n\nType DELETE to confirm.',
    field: const ShiftAlertField(placeholder: 'DELETE'),
    actions: <ShiftAlertAction<bool>>[
      const ShiftAlertAction<bool>('Cancel', value: false, isDefault: true),
      ShiftAlertAction<bool>(
        'Delete account',
        value: true,
        destructive: true,
        enabled: (String typed) => typed.trim().toUpperCase() == 'DELETE',
      ),
    ],
  );
  if (!(sure ?? false) || !context.mounted) return;

  final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
  final String? failed = await state.deleteAccount();
  bar.showSnackBar(
    SnackBar(
      content: Text(failed ?? 'Your account has been deleted.'),
    ),
  );
}
