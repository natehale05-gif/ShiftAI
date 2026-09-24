import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/theme/app_theme.dart';
import 'package:shift_ai/theme/tokens.dart';
import 'package:shift_ai/widgets/markdown_text.dart';

const String _reply = '''
### Shot list

A **tight** 20 second cut, *handheld*, see [the brief](https://x.test).

1. Hook: the ferry horn
2. The crossing
   - wide, then close
- ~~drone~~ no drone

> Keep it under 20 s.

```
ffmpeg -i in.mp4 -t 20 out.mp4
```
---
Use `ffmpeg` for the trim.''';

void main() {
  group('reading a reply', () {
    test('blocks, in order', () {
      final List<MdBlock> blocks = MdBlock.parse(_reply);
      expect(blocks.map((MdBlock b) => b.runtimeType.toString()), <String>[
        'MdHeading',
        'MdParagraph',
        'MdItem',
        'MdItem',
        'MdItem',
        'MdItem',
        'MdQuote',
        'MdCode',
        'MdRule',
        'MdParagraph',
      ]);
      final MdHeading heading = blocks.first as MdHeading;
      expect(heading.level, 3);
      expect(heading.text, 'Shot list');
      final MdItem first = blocks[2] as MdItem;
      expect(first.number, '1');
      final MdItem nested = blocks[4] as MdItem;
      expect(nested.depth, 1, reason: 'indented under item 2');
      expect(nested.number, isNull);
      expect((blocks[7] as MdCode).code, 'ffmpeg -i in.mp4 -t 20 out.mp4');
    });

    test('a code fence still open while it streams is code so far', () {
      final List<MdBlock> blocks = MdBlock.parse('Try:\n```\nnpm run');
      expect(blocks.last, isA<MdCode>());
      expect((blocks.last as MdCode).code, 'npm run');
    });

    test('an asterisk that is not emphasis stays an asterisk', () {
      final List<InlineSpan> spans = MarkdownText.inline(
        '2 * 3 = 6 and file_name_here',
        const TextStyle(),
        ShiftColors.forTheme(ShiftThemeId.values.first),
      );
      expect(TextSpan(children: spans).toPlainText(),
          '2 * 3 = 6 and file_name_here');
      expect(spans.length, 1, reason: 'no emphasis was found');
    });
  });

  testWidgets('the thread shows the words, not the Markdown',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ShiftTheme.build(ShiftThemeId.values.first),
        home: const Scaffold(
          body: SingleChildScrollView(child: MarkdownText(_reply)),
        ),
      ),
    );
    final String shown = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((RichText r) => r.text.toPlainText())
        .join('\n');
    expect(shown, contains('Shot list'));
    expect(shown, contains('A tight 20 second cut, handheld, see the brief.'));
    expect(shown, contains('Hook: the ferry horn'));
    expect(shown, isNot(contains('**')));
    expect(shown, isNot(contains('###')));
    expect(shown, isNot(contains('](')));
    expect(find.byTooltip('Copy code'), findsOneWidget);

    // The plain words are the paragraph's size, not the default text
    // style's: the root span carries it.
    final RichText paragraph = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((RichText r) => r.text.toPlainText().startsWith('A tight'));
    // Text.rich puts the default style outermost; ours is inside it.
    final InlineSpan ours = (paragraph.text as TextSpan).children!.single;
    expect(ours.style?.fontSize, 17);
  });
}
