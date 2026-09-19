import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/common.dart';

/// The gate. One card, email and password, and a plain line about what the
/// membership already covers.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _refused;

  /// The obvious mistakes are caught here so they do not cost a round
  /// trip. The answer that matters comes from the engine, and whatever it
  /// says is what the person reads.
  Future<void> _submit(AppState state) async {
    final String email = _email.text.trim();
    final bool looksLikeEmail =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    setState(() {
      _refused = null;
      _emailError = email.isEmpty
          ? 'Enter the email your membership is under.'
          : looksLikeEmail
              ? null
              : 'That does not look like an email address.';
      _passwordError = _password.text.isEmpty ? 'Enter your password.' : null;
    });
    if (_emailError != null || _passwordError != null) return;

    final String? refused = await state.signIn(email, _password.text);
    if (!mounted) return;
    setState(() => _refused = refused);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Center(child: ShiftLogo(height: 30)),
                const SizedBox(height: Space.x7),
                ShiftCard(
                  padding: const EdgeInsets.all(Space.x6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('Sign in', style: ShiftType.heading(c.text)),
                      const SizedBox(height: Space.x2),
                      Text(
                        'Use the account your membership is under. There is '
                        'no separate plan to buy.',
                        style: ShiftType.bodySm(c.textMuted),
                      ),
                      const SizedBox(height: Space.x5),
                      Text('EMAIL', style: ShiftType.labelSm(c.textMuted)),
                      const SizedBox(height: Space.x2),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const <String>[AutofillHints.email],
                        style: ShiftType.body(c.text),
                        decoration: InputDecoration(
                          hintText: 'you@example.com',
                          errorText: _emailError,
                        ),
                        onChanged: _emailError == null
                            ? null
                            : (_) => setState(() => _emailError = null),
                      ),
                      const SizedBox(height: Space.x4),
                      Text('PASSWORD', style: ShiftType.labelSm(c.textMuted)),
                      const SizedBox(height: Space.x2),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const <String>[AutofillHints.password],
                        style: ShiftType.body(c.text),
                        decoration: InputDecoration(
                          hintText: 'Your password',
                          errorText: _passwordError,
                        ),
                        onChanged: _passwordError == null
                            ? null
                            : (_) => setState(() => _passwordError = null),
                        onSubmitted: (_) => _submit(state),
                      ),
                      const SizedBox(height: Space.x5),
                      FilledButton(
                        onPressed:
                            state.signingIn ? null : () => _submit(state),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: state.signingIn
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('SIGN IN'),
                      ),
                      // What the engine said, verbatim. A wrong password
                      // and an engine that is down are different problems,
                      // and the person is told which one they have.
                      if (_refused != null) ...<Widget>[
                        const SizedBox(height: Space.x4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: c.danger,
                            ),
                            const SizedBox(width: Space.x2),
                            Expanded(
                              child: Text(
                                _refused!,
                                style: ShiftType.bodySm(c.danger),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: Space.x5),
                      Container(
                        padding: const EdgeInsets.all(Space.x4),
                        decoration: BoxDecoration(
                          color: c.accentSoft,
                          borderRadius: Radii.mdAll,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.info_outline_rounded,
                              size: 20,
                              color: c.accent,
                            ),
                            const SizedBox(width: Space.x3),
                            Expanded(
                              child: Text(
                                'Every mode, the vault and the weekly board '
                                'are included with membership.',
                                style: ShiftType.bodySm(c.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.x4),
                      Center(
                        child: TextButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (BuildContext context) {
                              final ShiftColors d = ShiftColors.of(context);
                              return AlertDialog(
                                backgroundColor: d.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: Radii.lgAll,
                                ),
                                title: Text(
                                  'Trouble signing in',
                                  style: ShiftType.subheading(d.text),
                                ),
                                content: Text(
                                  'Membership is handled by SHIFT support. '
                                  'Mail support@shiftai.club with the address '
                                  'on your account and they can reset it.',
                                  style: ShiftType.bodySm(d.text),
                                ),
                                actions: <Widget>[
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('CLOSE'),
                                  ),
                                ],
                              );
                            },
                          ),
                          child: Text(
                            'Trouble signing in?',
                            style: ShiftType.bodySm(c.accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
