import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/common.dart';
import 'avatar.dart';

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
              const SizedBox(height: Space.x1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '@${state.creator.handle}',
                    style: ShiftType.bodySm(c.textMuted),
                  ),
                  const SizedBox(width: Space.x1),
                  InkWell(
                    onTap: () => _renameHandle(context),
                    borderRadius: Radii.smAll,
                    child: Padding(
                      padding: const EdgeInsets.all(Space.x1),
                      child: Icon(Icons.edit, size: 14, color: c.textMuted),
                    ),
                  ),
                ],
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
              'INCLUDED WITH MEMBERSHIP',
              style: ShiftType.labelSm(c.accent),
            ),
          ),
          OutlinedButton(
            onPressed: state.signOut,
            child: Text('Sign out', style: ShiftType.bodySm(c.text)),
          ),
          TextButton(
            onPressed: () => _deleteAccount(context),
            child: Text('Delete account', style: ShiftType.bodySm(c.danger)),
          ),
        ],
      ),
    );
  }
}

/// The username that attributes a person's work in EcoVault.
Future<void> _renameHandle(BuildContext context) async {
  final AppState state = AppScope.read(context);
  final TextEditingController controller =
      TextEditingController(text: state.creator.handle);
  final String? next = await showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      final ShiftColors c = ShiftColors.of(context);
      return AlertDialog(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: Text('Change username', style: ShiftType.subheading(c.text)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: ShiftType.bodySm(c.text),
          decoration: const InputDecoration(prefixText: '@'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('SAVE'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  final String trimmed = (next ?? '').trim();
  if (trimmed.isEmpty ||
      trimmed.contains(RegExp(r'\s')) ||
      trimmed == state.creator.handle ||
      !context.mounted) {
    return;
  }

  final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
  if (!await state.updateHandle(trimmed)) {
    bar.showSnackBar(
      SnackBar(
        content:
            Text(state.lastError?.message ?? 'Could not change username.'),
      ),
    );
  }
}

/// Apple requires an app that creates accounts to let people delete them
/// from inside the app (Guideline 5.1.1(v)). Typed confirmation rather
/// than a two-button dialog, because this one does not come back.
Future<void> _deleteAccount(BuildContext context) async {
  final AppState state = AppScope.read(context);
  final TextEditingController typed = TextEditingController();

  final bool? sure = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      final ShiftColors c = ShiftColors.of(context);
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheet) {
          final bool matches = typed.text.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            backgroundColor: c.surface,
            shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
            title: Text(
              'Delete your account?',
              style: ShiftType.subheading(c.text),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Your vault, your notes, your designs and your place on '
                  'the board go with it. This cannot be undone and support '
                  'cannot restore it.',
                  style: ShiftType.bodySm(c.textMuted),
                ),
                const SizedBox(height: Space.x4),
                Text('TYPE DELETE TO CONFIRM',
                    style: ShiftType.labelSm(c.textMuted)),
                const SizedBox(height: Space.x2),
                TextField(
                  controller: typed,
                  autofocus: true,
                  style: ShiftType.bodySm(c.text),
                  onChanged: (_) => setSheet(() {}),
                ),
              ],
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
                onPressed:
                    matches ? () => Navigator.of(context).pop(true) : null,
                child: const Text('DELETE ACCOUNT'),
              ),
            ],
          );
        },
      );
    },
  );
  typed.dispose();
  if (!(sure ?? false) || !context.mounted) return;

  final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
  final String? failed = await state.deleteAccount();
  bar.showSnackBar(
    SnackBar(
      content: Text(failed ?? 'Your account has been deleted.'),
    ),
  );
}
