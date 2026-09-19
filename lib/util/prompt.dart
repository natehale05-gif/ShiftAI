/// "Polish my prompt": turn a one-line ask into the fuller brief a
/// generation model actually needs, and hand it back so the person can
/// read and edit it before sending.
///
/// The hosted client sends the text to the model for this. Here the same
/// shape is produced locally, so the button behaves identically whether
/// or not a provider key is in place — and so it can be tested.
abstract final class Prompt {
  /// Already-polished text is left alone: pressing the sparkle twice
  /// should not stack briefs on top of each other.
  static bool isPolished(String text) => text.contains(_marker);

  static const String _marker = 'Deliver:';

  static String polish(String raw) {
    final String text = raw.trim();
    if (text.isEmpty || isPolished(text)) return text;

    final String ask = _stripLeadIn(text);
    final _Guess guess = _Guess.from(ask);

    final StringBuffer out = StringBuffer()
      ..writeln(_capitalise(ask.endsWith('.') ? ask : '$ask.'))
      ..writeln()
      ..writeln('Audience: ${guess.audience}.')
      ..writeln('Tone: ${guess.tone}.')
      ..writeln('Format: ${guess.format}.')
      ..write('Deliver: ${guess.deliverable}. '
          'Say what you assumed if anything here was unclear.');
    return out.toString();
  }

  /// "can you please make me a…" carries no information; the ask does.
  static String _stripLeadIn(String text) {
    String out = text;
    for (final RegExp lead in _leadIns) {
      out = out.replaceFirst(lead, '');
    }
    return out.trim().isEmpty ? text : out.trim();
  }

  static final List<RegExp> _leadIns = <RegExp>[
    RegExp(r'^\s*(hey|hi|hello)[,!.\s]+', caseSensitive: false),
    RegExp(
      r'^\s*(can|could|would)\s+you\s+(please\s+)?',
      caseSensitive: false,
    ),
    RegExp(r'^\s*(please|pls)\s+', caseSensitive: false),
    RegExp(r'^\s*i\s+(want|need|would like)\s+(you\s+to\s+)?',
        caseSensitive: false),
    RegExp(r'^\s*make\s+me\s+', caseSensitive: false),
  ];

  static String _capitalise(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

class _Guess {
  const _Guess({
    required this.audience,
    required this.tone,
    required this.format,
    required this.deliverable,
  });

  final String audience;
  final String tone;
  final String format;
  final String deliverable;

  static _Guess from(String ask) {
    final String a = ask.toLowerCase();

    bool has(List<String> words) => words.any(a.contains);

    if (has(<String>['video', 'promo', 'clip', 'reel', 'trailer', 'ad'])) {
      return const _Guess(
        audience: 'people meeting this for the first time',
        tone: 'confident, no filler',
        format: 'vertical 1080 × 1920, cuts on the beat',
        deliverable: 'one finished clip plus the shot list behind it',
      );
    }
    if (has(<String>['image', 'poster', 'cover', 'thumbnail', 'logo', 'art'])) {
      return const _Guess(
        audience: 'someone scrolling past at speed',
        tone: 'bold, legible at thumbnail size',
        format: 'one strong focal point, generous margins',
        deliverable: 'the image plus one alternate crop',
      );
    }
    if (has(<String>['write', 'copy', 'post', 'email', 'caption', 'script'])) {
      return const _Guess(
        audience: 'a reader who has not seen this before',
        tone: 'plain, specific, no marketing language',
        format: 'short paragraphs, no headings unless they earn their place',
        deliverable: 'the finished text, ready to send',
      );
    }
    if (has(<String>['code', 'app', 'build', 'component', 'fix', 'bug'])) {
      return const _Guess(
        audience: 'a developer picking this up cold',
        tone: 'direct, no hedging',
        format: 'working code with the reasoning kept short',
        deliverable: 'the change plus how it was checked',
      );
    }
    return const _Guess(
      audience: 'someone new to this',
      tone: 'plain and specific',
      format: 'whatever makes it easiest to act on',
      deliverable: 'the finished thing, not a plan for it',
    );
  }
}
