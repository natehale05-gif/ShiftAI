import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';

/// One button in a [showShiftAlert].
class ShiftAlertAction<T> {
  const ShiftAlertAction(
    this.label, {
    this.value,
    this.valueOf,
    this.destructive = false,
    this.isDefault = false,
    this.enabled,
  });

  final String label;

  /// What the alert returns when this is tapped.
  final T? value;

  /// For an alert with a field: what to return, given what is typed at
  /// the moment it is tapped. Wins over [value].
  final T? Function(String typed)? valueOf;

  /// Red, for an action that cannot be taken back.
  final bool destructive;

  /// Bold: the one to take if unsure. On iOS that is Cancel beside a
  /// destructive action, and the action itself otherwise.
  final bool isDefault;

  /// Given what is typed (empty without a field); null means always on.
  final bool Function(String typed)? enabled;
}

/// A text field inside a [showShiftAlert].
class ShiftAlertField {
  const ShiftAlertField({
    this.initial = '',
    this.placeholder,
    this.prefixText,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String initial;
  final String? placeholder;
  final String? prefixText;
  final int minLines;
  final int maxLines;
}

/// An Apple alert: centred title and message on the translucent card,
/// buttons along the bottom split by hairlines, a destructive action in
/// red and the safe one bold.
///
/// Every confirmation in the app goes through here. They used to be
/// Material AlertDialogs, left-aligned with filled buttons in the corner,
/// which is the most Android-looking thing an iPhone user could meet in
/// this app. Set in the app's own faces and tokens, not system blue.
///
/// With a [field], the alert owns its text controller and disposes it
/// once the alert has finished animating away. Callers used to dispose
/// theirs the moment the dialog returned, while its exit animation was
/// still drawing the field.
Future<T?> showShiftAlert<T>(
  BuildContext context, {
  required String title,
  String? message,
  ShiftAlertField? field,
  required List<ShiftAlertAction<T>> actions,
}) =>
    showCupertinoDialog<T>(
      context: context,
      builder: (BuildContext _) => _ShiftAlert<T>(
        title: title,
        message: message,
        field: field,
        actions: actions,
      ),
    );

class _ShiftAlert<T> extends StatefulWidget {
  const _ShiftAlert({
    required this.title,
    required this.message,
    required this.field,
    required this.actions,
    super.key,
  });

  final String title;
  final String? message;
  final ShiftAlertField? field;
  final List<ShiftAlertAction<T>> actions;

  @override
  State<_ShiftAlert<T>> createState() => _ShiftAlertState<T>();
}

class _ShiftAlertState<T> extends State<_ShiftAlert<T>> {
  late final TextEditingController _text =
      TextEditingController(text: widget.field?.initial ?? '');

  @override
  void initState() {
    super.initState();
    // Actions that depend on what is typed follow it as it is typed.
    _text.addListener(_typed);
  }

  void _typed() => setState(() {});

  @override
  void dispose() {
    _text
      ..removeListener(_typed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final String? message = widget.message;
    final ShiftAlertField? field = widget.field;
    final String typed = _text.text;

    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: c.isDarkGround ? Brightness.dark : Brightness.light,
        primaryColor: c.accent,
      ),
      child: CupertinoAlertDialog(
        title: Text(widget.title, style: ShiftType.headline(c.text)),
        content: message == null && field == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (message != null) ...<Widget>[
                    const SizedBox(height: Space.x1),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: ShiftType.caption(c.text),
                    ),
                  ],
                  if (field != null) ...<Widget>[
                    const SizedBox(height: Space.x3),
                    // A text field needs a Material above it; the alert is
                    // drawn outside the app's Scaffold.
                    Material(
                      type: MaterialType.transparency,
                      child: _Field(controller: _text, spec: field),
                    ),
                  ],
                ],
              ),
        actions: <Widget>[
          for (final ShiftAlertAction<T> a in widget.actions)
            CupertinoDialogAction(
              isDefaultAction: a.isDefault,
              isDestructiveAction: a.destructive,
              onPressed: (a.enabled?.call(typed) ?? true)
                  ? () => Navigator.of(context)
                      .pop(a.valueOf != null ? a.valueOf!(typed) : a.value)
                  : null,
              textStyle: ShiftType.copy(
                a.destructive ? c.danger : c.accent,
                size: 17,
                weight: a.isDefault ? 600 : 400,
              ),
              child: Text(a.label),
            ),
        ],
      ),
    );
  }
}

/// Compact, filled, rounded like the field in an iOS alert.
class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.spec});

  final TextEditingController controller;
  final ShiftAlertField spec;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return TextField(
      controller: controller,
      autofocus: true,
      minLines: spec.minLines,
      maxLines: spec.maxLines,
      style: ShiftType.bodySm(c.text),
      decoration: InputDecoration(
        isDense: true,
        hintText: spec.placeholder,
        prefixText: spec.prefixText,
        fillColor: c.bg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.x3,
          vertical: Space.x2,
        ),
        border: const OutlineInputBorder(
          borderRadius: Radii.smAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.smAll,
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.smAll,
          borderSide: BorderSide(color: c.accent),
        ),
      ),
    );
  }
}
