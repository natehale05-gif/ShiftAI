import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';

/// A reply as the model wrote it: Markdown, drawn in the app's own type.
///
/// Every model the Suite talks to answers in Markdown. The thread drew
/// the source as it was, so a reply read "**Hook:** ..." and "### Shot
/// list", asterisks and hashes included. This draws the part of Markdown
/// replies use: headings, lists (nested by indent), quotes, rules, code
/// blocks, and bold, italic, `code`, ~~struck~~ and [links](url) inline.
/// Anything else is shown as the text it is. Copy still hands over the
/// source, as Claude's does.
///
/// It is drawn as it arrives: an unclosed `**` or code fence while a reply
/// streams is shown as written until the rest of it lands.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.source, {this.style, super.key});

  final String source;

  /// The paragraph style; ShiftType.body in the text colour when null.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final TextStyle base = style ?? ShiftType.body(c.text);
    final List<MdBlock> blocks = MdBlock.parse(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < blocks.length; i++) ...<Widget>[
          if (i > 0)
            SizedBox(
              height: blocks[i] is MdItem && blocks[i - 1] is MdItem
                  ? Space.x1
                  : Space.x3,
            ),
          _block(context, c, base, blocks[i]),
        ],
      ],
    );
  }

  Widget _block(
    BuildContext context,
    ShiftColors c,
    TextStyle base,
    MdBlock block,
  ) {
    switch (block) {
      case MdHeading(:final int level, :final String text):
        final TextStyle style = level <= 2
            ? ShiftType.sectionTitle(c.text)
            : ShiftType.headline(c.text);
        return Semantics(
          header: true,
          child: _rich(text, style, c),
        );
      case MdParagraph(:final String text):
        return _rich(text, base, c);
      case MdItem(:final int depth, :final String? number, :final String text):
        return Padding(
          padding: EdgeInsets.only(left: depth * Space.x5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: number == null ? Space.x5 : Space.x6,
                child: number == null
                    ? Padding(
                        // The dot sits on the first line's x-height.
                        padding: EdgeInsets.only(
                          top:
                              (base.fontSize ?? 17) * (base.height ?? 1.4) / 2 -
                                  2,
                        ),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: c.textMuted,
                              borderRadius: Radii.pillAll,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        '$number.',
                        style: base.copyWith(
                          color: c.textMuted,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
              ),
              Expanded(
                child: _rich(text, base, c),
              ),
            ],
          ),
        );
      case MdQuote(:final String text):
        return Container(
          padding: const EdgeInsets.only(left: Space.x3),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: c.borderStrong, width: 3)),
          ),
          child: _rich(text, base.copyWith(color: c.textMuted), c),
        );
      case MdRule():
        return Divider(height: Space.x3, color: c.border);
      case MdCode(:final String code):
        return _CodeBlock(code: code);
    }
  }

  /// One run of text in [style]. The style is set on the root span: set
  /// only on the formatted parts, the plain words between them fell back
  /// to the default text style and came out smaller than the bold ones.
  static Widget _rich(String text, TextStyle style, ShiftColors c) =>
      Text.rich(TextSpan(style: style, children: inline(text, style, c)));

  /// Bold, italic, `code`, ~~struck~~ and [links](url) within one line or
  /// paragraph, nested where Markdown nests them ("**a *b* c**").
  static List<InlineSpan> inline(String text, TextStyle base, ShiftColors c) {
    final List<InlineSpan> out = <InlineSpan>[];
    int at = 0;
    for (final RegExpMatch m in _inline.allMatches(text)) {
      if (m.start > at) out.add(TextSpan(text: text.substring(at, m.start)));
      if (m.group(1) != null) {
        out.add(TextSpan(
          text: m.group(1),
          style: base.copyWith(
            backgroundColor: c.surfaceRaised,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ));
      } else if (m.group(2) != null || m.group(3) != null) {
        final TextStyle bold = _weight(base, 700);
        out.add(TextSpan(
          style: bold,
          children: inline(m.group(2) ?? m.group(3)!, bold, c),
        ));
      } else if (m.group(4) != null) {
        final TextStyle struck =
            base.copyWith(decoration: TextDecoration.lineThrough);
        out.add(
            TextSpan(style: struck, children: inline(m.group(4)!, struck, c)));
      } else if (m.group(5) != null) {
        final TextStyle link = base.copyWith(
          color: c.accent,
          decoration: TextDecoration.underline,
          decorationColor: c.accent,
        );
        out.add(TextSpan(style: link, children: inline(m.group(5)!, link, c)));
      } else {
        final TextStyle italic = base.copyWith(fontStyle: FontStyle.italic);
        out.add(TextSpan(
          style: italic,
          children: inline(m.group(7) ?? m.group(8)!, italic, c),
        ));
      }
      at = m.end;
    }
    if (at < text.length) out.add(TextSpan(text: text.substring(at)));
    return out;
  }

  /// The copy face is variable: a weight goes through its `wght` axis, or
  /// it changes nothing visible (see ShiftType.figures).
  static TextStyle _weight(TextStyle base, int weight) => base.copyWith(
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        fontVariations: <FontVariation>[
          FontVariation('wght', weight.toDouble()),
        ],
      );

  static final RegExp _inline = RegExp(
    r'`([^`\n]+)`'
    r'|\*\*(?=\S)(.+?)(?<=\S)\*\*'
    r'|__(?=\S)(.+?)(?<=\S)__'
    r'|~~(?=\S)(.+?)(?<=\S)~~'
    r'|\[([^\]\n]+)\]\(([^)\s]+)\)'
    r'|(?<![\w*])\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?![\w*])'
    r'|(?<![\w_])_(?=[^\s_])(.+?)(?<=[^\s_])_(?![\w_])',
  );
}

/// A code block: the source as written, scrolled sideways rather than
/// wrapped, with its own Copy.
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(color: c.border),
      ),
      child: Stack(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              Space.x4,
              Space.x3,
              Space.x7,
              Space.x3,
            ),
            child: Text(
              code,
              style: ShiftType.copy(c.text, size: 14, lineHeight: 21).copyWith(
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Copy code',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(content: Text('Code copied')),
                );
              },
              icon: Icon(
                Icons.content_copy_rounded,
                size: 16,
                color: c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One block of a reply, as [MdBlock.parse] reads it.
sealed class MdBlock {
  const MdBlock();

  static final RegExp _heading = RegExp(r'^(#{1,6})\s+(.*?)\s*#*\s*$');
  static final RegExp _rule = RegExp(r'^\s{0,3}([-*_])(\s*\1){2,}\s*$');
  static final RegExp _bullet = RegExp(r'^(\s*)[-*+]\s+(.*)$');
  static final RegExp _ordered = RegExp(r'^(\s*)(\d{1,3})[.)]\s+(.*)$');
  static final RegExp _quote = RegExp(r'^\s{0,3}>\s?(.*)$');
  static final RegExp _fence = RegExp(r'^\s{0,3}(```|~~~)');

  static List<MdBlock> parse(String source) {
    final List<MdBlock> out = <MdBlock>[];
    final List<String> lines = source.replaceAll('\r\n', '\n').split('\n');
    final List<String> paragraph = <String>[];
    final List<String> quote = <String>[];

    void endParagraph() {
      if (paragraph.isEmpty) return;
      out.add(MdParagraph(paragraph.join('\n')));
      paragraph.clear();
    }

    void endQuote() {
      if (quote.isEmpty) return;
      out.add(MdQuote(quote.join('\n')));
      quote.clear();
    }

    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      final RegExpMatch? fence = _fence.firstMatch(line);
      if (fence != null) {
        endParagraph();
        endQuote();
        final String mark = fence.group(1)!;
        final List<String> code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith(mark)) {
          code.add(lines[i]);
          i++;
        }
        out.add(MdCode(code.join('\n')));
        continue;
      }
      if (line.trim().isEmpty) {
        endParagraph();
        endQuote();
        continue;
      }
      final RegExpMatch? q = _quote.firstMatch(line);
      if (q != null) {
        endParagraph();
        quote.add(q.group(1)!);
        continue;
      }
      endQuote();
      final RegExpMatch? h = _heading.firstMatch(line);
      if (h != null) {
        endParagraph();
        out.add(MdHeading(h.group(1)!.length, h.group(2)!));
        continue;
      }
      if (_rule.hasMatch(line)) {
        endParagraph();
        out.add(const MdRule());
        continue;
      }
      final RegExpMatch? b = _bullet.firstMatch(line);
      if (b != null) {
        endParagraph();
        out.add(MdItem(_depth(b.group(1)!), null, b.group(2)!));
        continue;
      }
      final RegExpMatch? o = _ordered.firstMatch(line);
      if (o != null) {
        endParagraph();
        out.add(MdItem(_depth(o.group(1)!), o.group(2), o.group(3)!));
        continue;
      }
      // A line under a list item that is indented belongs to that item.
      if (paragraph.isEmpty &&
          out.isNotEmpty &&
          out.last is MdItem &&
          line.startsWith('  ')) {
        final MdItem item = out.removeLast() as MdItem;
        out.add(
            MdItem(item.depth, item.number, '${item.text}\n${line.trim()}'));
        continue;
      }
      paragraph.add(line);
    }
    endParagraph();
    endQuote();
    return out;
  }

  /// Two spaces (or a tab) of indent per level, at most three deep.
  static int _depth(String indent) =>
      (indent.replaceAll('\t', '    ').length ~/ 2).clamp(0, 3);
}

class MdParagraph extends MdBlock {
  const MdParagraph(this.text);
  final String text;
}

class MdHeading extends MdBlock {
  const MdHeading(this.level, this.text);
  final int level;
  final String text;
}

/// A list item; [number] for an ordered one, as the model numbered it.
class MdItem extends MdBlock {
  const MdItem(this.depth, this.number, this.text);
  final int depth;
  final String? number;
  final String text;
}

class MdQuote extends MdBlock {
  const MdQuote(this.text);
  final String text;
}

class MdRule extends MdBlock {
  const MdRule();
}

class MdCode extends MdBlock {
  const MdCode(this.code);
  final String code;
}
