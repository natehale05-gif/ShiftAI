import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/theme/app_theme.dart';
import 'package:shift_ai/theme/tokens.dart';
import 'package:shift_ai/widgets/alert.dart';

/// A page with one button that opens [open] and keeps what it returned.
Future<List<Object?>> _host(
  WidgetTester tester,
  Future<Object?> Function(BuildContext) open,
) async {
  final List<Object?> results = <Object?>[];
  await tester.pumpWidget(MaterialApp(
    theme: ShiftTheme.build(ShiftThemeId.values.first),
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => Center(
          child: TextButton(
            onPressed: () async => results.add(await open(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

CupertinoDialogAction _action(WidgetTester tester, String label) =>
    tester.widget<CupertinoDialogAction>(find.ancestor(
      of: find.text(label),
      matching: find.byType(CupertinoDialogAction),
    ));

void main() {
  testWidgets('a confirmation is an Apple alert: Cancel bold, Delete red',
      (WidgetTester tester) async {
    final List<Object?> results = await _host(
      tester,
      (BuildContext context) => showShiftAlert<bool>(
        context,
        title: 'Delete this note?',
        message: 'It goes for good.',
        actions: const <ShiftAlertAction<bool>>[
          ShiftAlertAction<bool>('Cancel', value: false, isDefault: true),
          ShiftAlertAction<bool>('Delete', value: true, destructive: true),
        ],
      ),
    );

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('It goes for good.'), findsOneWidget);
    expect(_action(tester, 'Cancel').isDefaultAction, isTrue);
    final CupertinoDialogAction delete = _action(tester, 'Delete');
    expect(delete.isDestructiveAction, isTrue);
    final ShiftColors c = ShiftColors.forTheme(ShiftThemeId.values.first);
    expect(delete.textStyle?.color, c.danger);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(results, <Object?>[true]);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });

  testWidgets(
      'a field: Save follows what is typed, returns it, and closing does '
      'not use a disposed controller', (WidgetTester tester) async {
    final List<Object?> results = await _host(
      tester,
      (BuildContext context) => showShiftAlert<String>(
        context,
        title: 'Rename',
        field: const ShiftAlertField(initial: 'Old', placeholder: 'Title'),
        actions: <ShiftAlertAction<String>>[
          const ShiftAlertAction<String>('Cancel'),
          ShiftAlertAction<String>(
            'Save',
            isDefault: true,
            valueOf: (String typed) => typed,
            enabled: (String typed) => typed.trim().isNotEmpty,
          ),
        ],
      ),
    );

    expect(_action(tester, 'Save').onPressed, isNotNull);
    await tester.enterText(find.byType(TextField), '  ');
    await tester.pump();
    expect(_action(tester, 'Save').onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'New title');
    await tester.pump();
    await tester.tap(find.text('Save'));
    // Through the whole exit animation: the field is still drawn while
    // the alert fades, which is when a caller-disposed controller threw.
    await tester.pumpAndSettle();
    expect(results, <Object?>['New title']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing DELETE is what unlocks deleting the account',
      (WidgetTester tester) async {
    final List<Object?> results = await _host(
      tester,
      (BuildContext context) => showShiftAlert<bool>(
        context,
        title: 'Delete your account?',
        field: const ShiftAlertField(placeholder: 'DELETE'),
        actions: <ShiftAlertAction<bool>>[
          const ShiftAlertAction<bool>('Cancel', value: false),
          ShiftAlertAction<bool>(
            'Delete account',
            value: true,
            destructive: true,
            enabled: (String typed) => typed.trim().toUpperCase() == 'DELETE',
          ),
        ],
      ),
    );

    expect(_action(tester, 'Delete account').onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(results, <Object?>[true]);
  });
}
