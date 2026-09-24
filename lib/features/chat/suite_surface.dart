import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/modes.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../util/choices.dart';
import '../../util/haptics.dart';
import '../../widgets/common.dart';
import 'failure_card.dart';
import '../../widgets/alert.dart';

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
        // Above the composer rather than instead of it. The bar is not
        // only a send button: Vault's Re-run hands it a draft and the
        // sparkle rewrites what is in it, and both should still work
        // while there is nobody to send to.
        if (state.chatNeedsSignIn) const _SignInToChat(),
        // Which AI answers next. Only when the server has connected more
        // than one: with one, or none listed, there is nothing to choose.
        if (!state.chatNeedsSignIn && state.chatModels.length > 1)
          const _ModelLine(),
        PillComposer(
          hint: state.privateChat
              ? 'Private chat — nothing here is saved'
              : 'Ask anything',
          showSparkle: true,
          showAvatarPicker: true,
          onSend: state.sendMessage,
        ),
      ],
    );
  }
}

/// The standing notice above the composer when nobody is signed in.
///
/// It says so before anything is typed rather than only on send, so the
/// bar is never a box you fill in and are then refused from.
class _SignInToChat extends StatelessWidget {
  const _SignInToChat();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.x5, 0, Space.x5, Space.x3),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            padding: const EdgeInsets.all(Space.x4),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: Radii.lgAll,
              border: Border.all(color: c.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: c.textMuted,
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Sign in to use chat.',
                        style: ShiftType.bodyStrong(c.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chat needs an account. Nothing you type here is '
                        'sent anywhere yet.',
                        style: ShiftType.caption(c.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x3),
                // signOut() is what puts the sign-in screen up. On the
                // seeded demo it keeps the vault, notes and standings —
                // only the thread and the avatar go — so this is a way in
                // rather than a way to lose what is on screen.
                // Filled: it is the card's one action, so it is drawn as the
                // prominent one. The outline version measured 2.5:1 on the
                // light themes, under the 4.5:1 text needs.
                FilledButton(
                  onPressed: state.signOut,
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
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
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.x5),
        child: Text(
          // Rotates — a new line per thread and per return to the app.
          // See `Greetings` for why it is not one fixed sentence.
          state.greeting,
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
              child: Text('Sign in', style: ShiftType.caption(c.accent)),
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

    // A question with answers to tap, on the newest reply only: once
    // something has been said after it, it has been answered, and the
    // older reply reads as it was written.
    final bool latest = state.messages.isNotEmpty &&
        identical(state.messages.last, message) &&
        !state.thinking &&
        !state.chatNeedsSignIn;
    final OfferedChoices? offer = latest ? OfferedChoices.of(message) : null;
    final String body = offer?.body ?? message.body;
    final bool showBullets =
        message.bullets.isNotEmpty && !(offer?.hideBullets ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Who wrote this reply, when the engine says. With several AIs in
        // one conversation this is how you tell them apart; each of them
        // reads the others' replies as its own.
        if (message.modelName != null) ...<Widget>[
          Text(
            message.modelName!,
            style: ShiftType.copy(c.textMuted, size: 13, weight: 600),
          ),
          const SizedBox(height: Space.x2),
        ],
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
        if (body.isNotEmpty) Text(body, style: ShiftType.body(c.text)),
        if (showBullets) ...<Widget>[
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
        if (offer != null) ...<Widget>[
          const SizedBox(height: Space.x4),
          ChoiceButtons(
            key: ValueKey<String>('choices-${message.id}'),
            offer: offer,
            onAnswer: state.sendMessage,
          ),
        ],
        const SizedBox(height: Space.x2),
        _MessageActions(message: message),
      ],
    );
  }
}

/// A reply's question, answered with a tap: one button per answer, the
/// way Claude asks. One tap sends that answer as your message. When it
/// asks for several, each tap ticks one and Send sends them together.
/// Typing in the bar still works for anything the buttons do not cover.
class ChoiceButtons extends StatefulWidget {
  const ChoiceButtons({
    required this.offer,
    required this.onAnswer,
    super.key,
  });

  final OfferedChoices offer;

  /// Sends the answer; false when it could not be sent.
  final bool Function(String answer) onAnswer;

  @override
  State<ChoiceButtons> createState() => _ChoiceButtonsState();
}

class _ChoiceButtonsState extends State<ChoiceButtons> {
  final Set<ChatChoice> _picked = <ChatChoice>{};

  /// Set once an answer has gone, so a second tap before the reply lands
  /// cannot send a second answer.
  bool _sent = false;

  void _send(Iterable<ChatChoice> picked) {
    if (_sent) return;
    final String answer = widget.offer.answer(picked);
    if (answer.isEmpty) return;
    Haptics.light();
    if (widget.onAnswer(answer)) setState(() => _sent = true);
  }

  void _tap(ChatChoice choice) {
    if (!widget.offer.multiSelect) {
      _send(<ChatChoice>[choice]);
      return;
    }
    Haptics.selection();
    setState(() {
      if (!_picked.remove(choice)) _picked.add(choice);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final OfferedChoices offer = widget.offer;
    final bool multi = offer.multiSelect;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < offer.choices.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: Space.x2),
          _ChoiceButton(
            number: i + 1,
            choice: offer.choices[i],
            multi: multi,
            picked: _picked.contains(offer.choices[i]),
            onTap: _sent ? null : () => _tap(offer.choices[i]),
          ),
        ],
        const SizedBox(height: Space.x2),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                multi
                    ? 'Pick any that fit, or type your own below.'
                    : 'Or type your own answer below.',
                style: ShiftType.caption(c.textMuted),
              ),
            ),
            if (multi)
              FilledButton(
                onPressed:
                    _picked.isEmpty || _sent ? null : () => _send(_picked),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                child: Text(
                  _picked.isEmpty ? 'Send' : 'Send ${_picked.length}',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.number,
    required this.choice,
    required this.multi,
    required this.picked,
    required this.onTap,
  });

  final int number;
  final ChatChoice choice;
  final bool multi;
  final bool picked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final String? detail = choice.description;

    return Semantics(
      button: true,
      toggled: multi ? picked : null,
      child: Material(
        color: picked ? c.accentSoft : c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: picked ? c.accent : c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x3,
                vertical: Space.x3,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: picked ? c.accent : c.surface,
                      borderRadius: Radii.smAll,
                      border: Border.all(color: picked ? c.accent : c.border),
                    ),
                    child: multi && picked
                        ? Icon(Icons.check_rounded, size: 16, color: c.onAccent)
                        : Text(
                            '$number',
                            style: ShiftType.copy(
                              picked ? c.onAccent : c.textMuted,
                              size: 13,
                              weight: 600,
                            ),
                          ),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          choice.label,
                          style: ShiftType.copy(c.text, size: 15, weight: 600),
                        ),
                        if (detail != null)
                          Text(detail, style: ShiftType.caption(c.textMuted)),
                      ],
                    ),
                  ),
                  if (!multi)
                    Icon(Icons.arrow_forward_rounded,
                        size: 18, color: c.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
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
          style: ShiftType.caption(c.textMuted),
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
        ...message.choices.map((ChatChoice c) => '• ${c.label}'),
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

  final String? next = await showShiftAlert<String>(
    context,
    title: 'Edit and send again',
    field: ShiftAlertField(initial: asked, minLines: 2, maxLines: 8),
    actions: <ShiftAlertAction<String>>[
      const ShiftAlertAction<String>('Cancel'),
      ShiftAlertAction<String>(
        'Send',
        isDefault: true,
        valueOf: (String typed) => typed,
        enabled: (String typed) => typed.trim().isNotEmpty,
      ),
    ],
  );
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

/// "Answering: Claude Opus 5.5" over the composer. Tapping it picks which
/// connected AI answers the next message. Switching mid-conversation is
/// the point: the next model reads the whole thread, the other models'
/// replies included, and carries on from them.
class _ModelLine extends StatelessWidget {
  const _ModelLine();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final ChatModel? picked = state.chatModel;
    final String name = picked?.name ?? 'Auto';

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.x5, Space.x1, Space.x5, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: true,
          label: 'Answering: $name. Change which AI answers.',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: Radii.pillAll,
            onTap: () => _pickModel(context, state),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.x2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.hub_outlined, size: 16, color: c.textMuted),
                    const SizedBox(width: Space.x2),
                    Text(
                      'Answering: ',
                      style: ShiftType.copy(c.textMuted, size: 15),
                    ),
                    // A model's name has no length limit; it shrinks
                    // before the line runs off the screen.
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShiftType.copy(c.accent, size: 15, weight: 600),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: c.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _pickModel(BuildContext context, AppState state) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (BuildContext context) {
      final ShiftColors c = ShiftColors.of(context);
      Widget option({
        required String? id,
        required String name,
        required String detail,
      }) {
        final bool on = state.chatModel?.id == id;
        return InkWell(
          onTap: () {
            Haptics.selection();
            state.setChatModel(id);
            Navigator.of(context).pop();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          style: ShiftType.copy(c.text, size: 16, weight: 600),
                        ),
                        if (detail.isNotEmpty)
                          Text(detail, style: ShiftType.caption(c.textMuted)),
                      ],
                    ),
                  ),
                  if (on) Icon(Icons.check_rounded, color: c.accent, size: 22),
                ],
              ),
            ),
          ),
        );
      }

      final ChatModel? fallback =
          state.chatModels.where((ChatModel m) => m.isDefault).firstOrNull;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.x5,
            Space.x4,
            Space.x5,
            Space.x5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  'Who answers',
                  style: ShiftType.sectionTitle(c.text),
                ),
              ),
              const SizedBox(height: Space.x1),
              Text(
                'Switch at any point. The next one reads the whole '
                'conversation, every reply included, and carries on from it.',
                style: ShiftType.bodySm(c.textMuted),
              ),
              const SizedBox(height: Space.x4),
              GroupedList(
                children: <Widget>[
                  option(
                    id: null,
                    name: 'Auto',
                    detail: fallback == null
                        ? 'The server picks'
                        : 'The server picks · usually ${fallback.name}',
                  ),
                  for (final ChatModel m in state.chatModels)
                    option(id: m.id, name: m.name, detail: m.provider),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
