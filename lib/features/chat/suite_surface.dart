import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/modes.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/common.dart';
import 'failure_card.dart';

/// Create: one question, one composer. The thread only appears once you
/// have asked for something.
class SuiteSurface extends StatefulWidget {
  const SuiteSurface({super.key});

  @override
  State<SuiteSurface> createState() => _SuiteSurfaceState();
}

class _SuiteSurfaceState extends State<SuiteSurface> {
  final ScrollController _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Anything new in the thread brings the thread with it, rather than
  /// landing below the fold and waiting to be found.
  void _followTheThread() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final bool empty = state.messages.isEmpty;
    final int count = state.messages.length + (state.thinking ? 1 : 0);

    if (count != _lastCount) {
      _lastCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) => _followTheThread());
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: empty
              ? const _EmptyState()
              : Scrollbar(
                  controller: _scroll,
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                      Space.x5,
                      Space.x6,
                      Space.x5,
                      Space.x5,
                    ),
                    itemCount: count,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Space.x5),
                    itemBuilder: (BuildContext context, int index) {
                      final bool isPending =
                          state.thinking && index == count - 1;
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: isPending
                              ? const _Thinking()
                              : _MessageTile(message: state.messages[index]),
                        ),
                      );
                    },
                  ),
                ),
        ),
        PillComposer(
          hint: state.privateChat
              ? 'Private chat — nothing here is saved'
              : 'Ask anything',
          showSparkle: true,
          onSend: state.sendMessage,
        ),
      ],
    );
  }
}

/// The beat between asking and being answered.
class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: Radii.pillAll,
              ),
            ),
          ),
          const SizedBox(width: Space.x2),
          const Eyebrow('Working'),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.x5),
        child: Text(
          'What are we making today?',
          textAlign: TextAlign.center,
          style: ShiftType.heading(c.textMuted),
        ),
      ),
    );
  }
}

/// What a plan-check failure becomes when nobody is signed in to a plan:
/// one line and a way to fix it, not a details disclosure about an outage
/// that was never real.
class _SignInBubble extends StatelessWidget {
  const _SignInBubble();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x3,
        ),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: Radii.lgAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Sign in to run this for real.',
                style: ShiftType.bodySm(c.textMuted)),
            const SizedBox(width: Space.x3),
            TextButton(
              onPressed: () => state.setSurface(Surface.settings),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('SIGN IN', style: ShiftType.labelSm(c.accent)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);

    if (message.failure != null) {
      // The full card names a real backend failure (a plan check that
      // could not be reached). Nobody is signed in to a plan yet in the
      // demo, so that reads as a scary, made-up outage — a short nudge to
      // sign in says the true thing instead.
      return state.seededDemo
          ? const _SignInBubble()
          : FailureCard(failure: message.failure!);
    }

    if (message.author == MessageAuthor.you) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x4,
              vertical: Space.x3,
            ),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: Radii.lgAll,
            ),
            child: Text(message.body, style: ShiftType.bodySm(c.text)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (message.eyebrow != null) ...<Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: Radii.pillAll,
                ),
              ),
              const SizedBox(width: Space.x2),
              Eyebrow(message.eyebrow!),
            ],
          ),
          const SizedBox(height: Space.x3),
        ],
        if (message.body.isNotEmpty)
          Text(message.body, style: ShiftType.body(c.text)),
        if (message.bullets.isNotEmpty) ...<Widget>[
          const SizedBox(height: Space.x3),
          ...message.bullets.map(
            (String line) => Padding(
              padding: const EdgeInsets.only(bottom: Space.x1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 9, right: Space.x3),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.textMuted,
                        borderRadius: Radii.pillAll,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(line, style: ShiftType.bodySm(c.text)),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (message.attachment != null) ...<Widget>[
          const SizedBox(height: Space.x4),
          ArtifactCard(attachment: message.attachment!),
        ],
        const SizedBox(height: Space.x2),
        _MessageActions(message: message),
      ],
    );
  }
}

/// The artifact card: what a generation produced, with the one action that
/// matters — open it where it lives.
class ArtifactCard extends StatelessWidget {
  const ArtifactCard({required this.attachment, super.key});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final bool video = attachment.kind == MediaKind.video;

    // With the Vault switched off there is nowhere for this to go, and a
    // button that silently returns you to Suite is worse than no button.
    final bool canOpen = state.isEnabled(ShiftFeature.vault);

    void open() {
      state.selectVaultItem(attachment.vaultItemId);
      state.setSurface(Surface.vault);
    }

    final Widget thumb = Container(
      width: 44,
      height: 60,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: Radii.smAll,
        border: Border.all(color: c.borderStrong),
      ),
      child: Icon(
        video ? Icons.play_arrow_rounded : Icons.image_outlined,
        size: 18,
        color: c.sky,
      ),
    );

    final Widget label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          attachment.fileName,
          style: ShiftType.bodyStrong(c.text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          attachment.meta,
          style: ShiftType.labelSm(c.textMuted),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.lgAll,
        border: Border.all(color: c.border),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    thumb,
                    const SizedBox(width: Space.x3),
                    Expanded(child: label),
                  ],
                ),
                if (canOpen) ...<Widget>[
                  const SizedBox(height: Space.x3),
                  OutlinedButton(
                    onPressed: open,
                    child:
                        Text('Open in Vault', style: ShiftType.bodySm(c.text)),
                  ),
                ],
              ],
            );
          }

          return Row(
            children: <Widget>[
              thumb,
              const SizedBox(width: Space.x4),
              Expanded(child: label),
              if (canOpen) ...<Widget>[
                const SizedBox(width: Space.x3),
                OutlinedButton(
                  onPressed: open,
                  child: Text('Open in Vault', style: ShiftType.bodySm(c.text)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MessageActions extends StatelessWidget {
  const _MessageActions({required this.message});

  final ChatMessage message;

  /// Everything the answer said, as one block, so Copy hands over the whole
  /// thing rather than the first paragraph.
  String get _plainText => <String>[
        if (message.body.isNotEmpty) message.body,
        ...message.bullets.map((String b) => '• $b'),
        if (message.attachment != null)
          '${message.attachment!.fileName} — ${message.attachment!.meta}',
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);

    void toast(String text) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));

    return Row(
      children: <Widget>[
        _MessageAction(
          icon: Icons.content_copy_rounded,
          label: 'Copy',
          color: c.textMuted,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _plainText));
            toast('Copied');
          },
        ),
        _MessageAction(
          icon: Icons.refresh_rounded,
          label: 'Retry',
          color: c.textMuted,
          onPressed: () {
            final String? asked = state.lastAsk;
            if (asked == null) {
              toast('Nothing to retry yet.');
              return;
            }
            state.sendMessage(asked);
          },
        ),
        _MessageAction(
          icon: Icons.edit_outlined,
          label: 'Edit',
          color: c.textMuted,
          onPressed: () => _editLastAsk(context, state),
        ),
      ],
    );
  }
}

/// Edit reopens what you asked for, so you can change it and send again
/// instead of retyping the whole thing.
Future<void> _editLastAsk(BuildContext context, AppState state) async {
  final String? asked = state.lastAsk;
  if (asked == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nothing to edit yet.')),
    );
    return;
  }

  final TextEditingController controller = TextEditingController(text: asked);
  final String? next = await showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      final ShiftColors c = ShiftColors.of(context);
      return AlertDialog(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: Text('Edit and send again', style: ShiftType.subheading(c.text)),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 8,
          style: ShiftType.bodySm(c.text),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('SEND'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  if (next != null && next.trim().isNotEmpty) state.sendMessage(next.trim());
}

class _MessageAction extends StatelessWidget {
  const _MessageAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: color),
      label: Text(label, style: ShiftType.caption(color)),
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: Space.x2),
      ),
    );
  }
}
