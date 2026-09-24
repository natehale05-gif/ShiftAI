import '../models/models.dart';

/// What a reply offers to tap, and the text left to show above the
/// buttons.
///
/// A server that follows docs/API.md sends `choices` with the reply, and
/// those are used as they are. Most models, asked a question of their own
/// and given no tool for it, write it out instead:
///
///     Which feel are you going for?
///     1. Cinematic — slow drone shots at sunset
///     2. Nightlife
///     3. Beach day
///
/// so that shape is recognised too, and the listed lines move from the
/// text into the buttons rather than being shown twice. It is kept narrow
/// on purpose: a question that ends the reply, and two to
/// [ChatChoice.max] short options right against it. A reply that is a
/// list of steps with a question somewhere in it stays text.
class OfferedChoices {
  const OfferedChoices({
    required this.choices,
    required this.multiSelect,
    required this.body,
    required this.hideBullets,
  });

  final List<ChatChoice> choices;
  final bool multiSelect;

  /// The reply's text with any options that became buttons taken out.
  final String body;

  /// True when the reply's bullets became the buttons.
  final bool hideBullets;

  /// What is sent when [picked] are chosen: one label, or several joined
  /// in the order they were offered.
  String answer(Iterable<ChatChoice> picked) {
    final List<String> labels = <String>[
      for (final ChatChoice c in choices)
        if (picked.contains(c)) c.label,
    ];
    if (labels.length <= 1) return labels.join();
    return '${labels.sublist(0, labels.length - 1).join(', ')} and '
        '${labels.last}';
  }

  static const int _longestLabel = 80;

  static OfferedChoices? of(ChatMessage m) {
    if (m.author == MessageAuthor.you || m.failure != null) return null;
    if (m.choices.isNotEmpty) {
      return OfferedChoices(
        choices: m.choices,
        multiSelect: m.multiSelect,
        body: m.body,
        hideBullets: false,
      );
    }

    final String body = m.body.trimRight();
    // The bullets field, under a body that ends in the question.
    if (_endsInQuestion(body) &&
        m.bullets.length >= 2 &&
        m.bullets.length <= ChatChoice.max) {
      final List<ChatChoice>? parsed = _parse(m.bullets);
      if (parsed != null) {
        return OfferedChoices(
          choices: parsed,
          multiSelect: _asksForSeveral(_lastLine(body)),
          body: m.body,
          hideBullets: true,
        );
      }
    }
    if (m.bullets.isNotEmpty) return null;

    final List<String> lines = body.split('\n');
    // Question, then the options to the end of the reply.
    final int q = _lastQuestionLine(lines);
    if (q >= 0 && q < lines.length - 1) {
      final List<String> after = lines
          .sublist(q + 1)
          .where((String l) => l.trim().isNotEmpty)
          .toList();
      final List<String>? options = _optionLines(after);
      if (options != null) {
        final List<ChatChoice>? parsed = _parse(options);
        if (parsed != null) {
          return OfferedChoices(
            choices: parsed,
            multiSelect: _asksForSeveral(lines[q]),
            body: lines.sublist(0, q + 1).join('\n').trimRight(),
            hideBullets: false,
          );
        }
      }
    }
    // Options, then the question as the reply's last line.
    if (q == lines.length - 1 && q > 0) {
      int start = q;
      while (start > 0 &&
          (lines[start - 1].trim().isEmpty ||
              _option.hasMatch(lines[start - 1]))) {
        start--;
      }
      final List<String> before = lines
          .sublist(start, q)
          .where((String l) => l.trim().isNotEmpty)
          .toList();
      final List<String>? options = _optionLines(before);
      if (options != null) {
        final List<ChatChoice>? parsed = _parse(options);
        if (parsed != null) {
          return OfferedChoices(
            choices: parsed,
            multiSelect: _asksForSeveral(lines[q]),
            body: <String>[
              ...lines.sublist(0, start),
              '',
              lines[q],
            ].join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim(),
            hideBullets: false,
          );
        }
      }
    }
    return null;
  }

  static final RegExp _option = RegExp(
    r'^\s*(?:[-*•]|\d{1,2}[.)]|[A-Ha-h][.)])\s+(.+?)\s*$',
  );

  /// Every line an option, and between two and [ChatChoice.max] of them.
  static List<String>? _optionLines(List<String> lines) {
    if (lines.length < 2 || lines.length > ChatChoice.max) return null;
    final List<String> out = <String>[];
    for (final String line in lines) {
      final RegExpMatch? m = _option.firstMatch(line);
      if (m == null) return null;
      out.add(m.group(1)!);
    }
    return out;
  }

  static List<ChatChoice>? _parse(List<String> raw) {
    final List<ChatChoice> out = <ChatChoice>[];
    for (final String line in raw) {
      final ChatChoice? c = _choice(line);
      if (c == null) return null;
      out.add(c);
    }
    // Two identical buttons would send the same answer either way.
    return out.map((ChatChoice c) => c.label).toSet().length == out.length
        ? out
        : null;
  }

  /// "**Cinematic** — slow drone shots" is a label and its detail.
  static ChatChoice? _choice(String line) {
    final String text = line.replaceAll('**', '').replaceAll('__', '').trim();
    if (text.isEmpty) return null;
    for (final String sep in <String>[' — ', ' – ', ' - ', ': ']) {
      final int at = text.indexOf(sep);
      if (at > 0 && at <= 40) {
        final String label = text.substring(0, at).trim();
        final String detail = text.substring(at + sep.length).trim();
        if (label.isNotEmpty && detail.isNotEmpty) {
          return ChatChoice(label, description: detail);
        }
      }
    }
    if (text.length > _longestLabel) return null;
    return ChatChoice(text);
  }

  static String _lastLine(String body) {
    final List<String> lines =
        body.split('\n').where((String l) => l.trim().isNotEmpty).toList();
    return lines.isEmpty ? '' : lines.last;
  }

  static bool _endsInQuestion(String body) => _isQuestion(_lastLine(body));

  /// Ends in "?", or asks and then says how to answer: "Where will it go?
  /// Pick any that fit." is as much a question as "Where will it go?".
  static bool _isQuestion(String line) {
    final String text = line.trimRight();
    final int mark = text.lastIndexOf('?');
    return mark >= 0 && text.length - mark - 1 <= 40;
  }

  static int _lastQuestionLine(List<String> lines) {
    for (int i = lines.length - 1; i >= 0; i--) {
      final String line = lines[i].trimRight();
      if (line.isEmpty || _option.hasMatch(line)) continue;
      return _isQuestion(line) ? i : -1;
    }
    return -1;
  }

  static final RegExp _several = RegExp(
    r'\b(all that apply|any of|which ones|pick (?:any|several|as many)|'
    r'choose (?:any|several|as many)|select (?:any|all|several)|'
    r'one or more)\b',
    caseSensitive: false,
  );

  static bool _asksForSeveral(String question) => _several.hasMatch(question);
}
