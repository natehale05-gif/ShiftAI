import '../models/models.dart';

/// Best fit: one model per message, the one suited to what it asks.
///
/// A message is read for what it wants made or done ([kindOf]); the
/// model whose `bestFor` covers that answers it. Anything no specialist
/// covers ("make it shorter", "thanks", a plain question) stays with the
/// model that answered last, so a conversation does not hop between AIs
/// on every reply; with no one yet, it goes to the server's default. When
/// none of that settles it, the pick is null and the server chooses.
abstract final class ModelRouter {
  static final Map<TaskKind, RegExp> _asks = <TaskKind, RegExp>{
    TaskKind.video: _words(<String>[
      'video',
      'videos',
      'clip',
      'reel',
      'reels',
      'trailer',
      'promo',
      'animation',
      'animate',
      'footage',
      'tiktok',
      'b-roll',
      'storyboard',
    ]),
    TaskKind.image: _words(<String>[
      'image',
      'images',
      'picture',
      'photo',
      'poster',
      'logo',
      'thumbnail',
      'illustration',
      'illustrate',
      'draw',
      'drawing',
      'wallpaper',
      'icon',
      'artwork',
      'cover art',
      'headshot',
      'portrait',
      'render',
    ]),
    TaskKind.audio: _words(<String>[
      'song',
      'music',
      'beat',
      'voiceover',
      'voice over',
      'narrate',
      'narration',
      'podcast',
      'jingle',
      'sound effect',
      'audio',
      'soundtrack',
    ]),
    TaskKind.code: _words(<String>[
      'code',
      'function',
      'bug',
      'debug',
      'stack trace',
      'exception',
      'python',
      'javascript',
      'typescript',
      'dart',
      'flutter',
      'sql',
      'regex',
      'compile',
      'refactor',
      'api',
      'script in',
    ]),
    TaskKind.research: _words(<String>[
      'research',
      'sources',
      'cite',
      'latest',
      'news',
      'look up',
      'find out',
      'compare',
      'statistics',
      'market size',
    ]),
    TaskKind.writing: _words(<String>[
      'write',
      'caption',
      'email',
      'blog',
      'essay',
      'copy',
      'headline',
      'rewrite',
      'proofread',
      'post',
      'newsletter',
      'article',
    ]),
  };

  static RegExp _words(List<String> words) => RegExp(
        '\\b(?:${words.map(RegExp.escape).join('|')})\\b',
        caseSensitive: false,
      );

  /// Asking for the thing itself: "make a video", "generate a logo".
  static final RegExp _make = _words(<String>[
    'make',
    'create',
    'generate',
    'render',
    'animate',
    'design',
    'draw',
    'produce',
    'shoot',
    'edit',
    'compose',
    'record',
    'paint',
    'sketch',
  ]);

  /// Asking for words: "write about the clip" is writing, not a video.
  static final RegExp _write = _words(<String>[
    'write',
    'draft',
    'rewrite',
    'summarise',
    'summarize',
    'describe',
    'explain',
    'translate',
    'proofread',
  ]);

  /// A piece of text, whatever it is for: "make me a caption for the
  /// video" is writing, as is a script, lyrics or a title, and so is a
  /// plan for one: a shot list, an outline, ideas. "Give me a shot list
  /// for the ferry reel" went to the video model and came back a video.
  static final RegExp _text = _words(<String>[
    'shot list',
    'outline',
    'ideas',
    'plan',
    'checklist',
    'tips',
    'strategy',
    'summary',
    'caption',
    'captions',
    'script',
    'scripts',
    'lyrics',
    'hashtags',
    'title',
    'titles',
    'description',
    'blurb',
    'bio',
    'tagline',
    'headline',
    'subject line',
  ]);

  /// A question: it ends in one, or opens like one.
  static final RegExp _question = RegExp(
    r'\?\s*$|^\s*(?:what|why|how|who|where|when|which|is|are|was|were|'
    r'can|could|does|do|did|should|would|will)\b',
    caseSensitive: false,
  );

  /// What [prompt] asks for, or null for talk no specialist covers.
  ///
  /// A piece of text is writing, whatever it is for. Otherwise a medium
  /// (video, image, audio) wins when the thing itself is asked for, or
  /// nothing is asked to be written: "make a video of Miami" is a video,
  /// "a poster for Friday" is an image, "describe this photo" is writing.
  static TaskKind? kindOf(String prompt) {
    if (_text.hasMatch(prompt)) return TaskKind.writing;
    final bool makes = _make.hasMatch(prompt);
    final bool writes = _write.hasMatch(prompt);
    // A question about a medium is not a request for one: "what is in
    // this photo?" went to the image model, which made a new picture.
    // "Can you make a video?" still asks for the thing itself.
    final bool asks = _question.hasMatch(prompt);
    for (final TaskKind k in <TaskKind>[
      TaskKind.video,
      TaskKind.image,
      TaskKind.audio,
    ]) {
      if (_asks[k]!.hasMatch(prompt) && (makes || (!writes && !asks))) {
        return k;
      }
    }
    for (final TaskKind k in <TaskKind>[
      TaskKind.code,
      TaskKind.research,
      TaskKind.writing,
    ]) {
      if (_asks[k]!.hasMatch(prompt)) return k;
    }
    return writes ? TaskKind.writing : null;
  }

  /// What only a model built for it can make. A chat model asked for an
  /// image writes about one instead, or describes what it would draw:
  /// never an answer to the ask, and it spends the credits anyway.
  static const Set<TaskKind> made = <TaskKind>{
    TaskKind.image,
    TaskKind.video,
    TaskKind.audio,
  };

  /// Who answers [prompt]: the model to send it to, or, when it asks for
  /// something only a specialist can make and none is connected, which
  /// kind is missing so the app can say so and send nothing.
  ///
  /// [picked] is a model chosen by hand. It answers everything except a
  /// thing it cannot make: a chat model picked by hand does not get the
  /// image request, a connected image model does.
  static ModelRoute route(
    List<ChatModel> models,
    String prompt, {
    ChatModel? picked,
    String? lastModelId,
  }) {
    final TaskKind? kind = kindOf(prompt);
    final bool madeThing = kind != null && made.contains(kind);
    // No list at all: words go to the server, which picks who answers.
    // A made thing does not. Left to choose, the preview answered
    // "generate an image of Miami" with its chat model ("I can't generate
    // images — I'm a text-based assistant"); an engine that has not said
    // which of its models make images is treated as having none.
    if (models.isEmpty) {
      return madeThing
          ? ModelRoute(null, missing: kind)
          : const ModelRoute(null);
    }
    if (madeThing) {
      final List<ChatModel> able =
          models.where((ChatModel m) => m.bestFor.contains(kind)).toList();
      if (able.isEmpty) return ModelRoute(null, missing: kind);
      final ChatModel? last =
          able.where((ChatModel m) => m.id == lastModelId).firstOrNull;
      if (picked != null && able.contains(picked)) return ModelRoute(picked);
      return ModelRoute(last ?? able.first);
    }
    return ModelRoute(picked ?? pick(models, prompt, lastModelId: lastModelId));
  }

  /// The one model to answer [prompt], given who answered last.
  static ChatModel? pick(
    List<ChatModel> models,
    String prompt, {
    String? lastModelId,
  }) {
    if (models.isEmpty) return null;
    ChatModel? byId(String? id) =>
        models.where((ChatModel m) => m.id == id).firstOrNull;
    final ChatModel? last = byId(lastModelId);
    final ChatModel? fallback =
        models.where((ChatModel m) => m.isDefault).firstOrNull;

    final TaskKind? kind = kindOf(prompt);
    if (kind != null) {
      final List<ChatModel> fit =
          models.where((ChatModel m) => m.bestFor.contains(kind)).toList();
      if (fit.isNotEmpty) {
        // The one already talking, if it fits too: no hop for nothing.
        return last != null && fit.contains(last) ? last : fit.first;
      }
    }
    // Something only a specialist makes, and none is here: nobody
    // answers it (route says why), least of all a chat model.
    if (kind != null && made.contains(kind)) return null;
    // Nobody specialises in this. A specialist that answered last (the
    // image model, say) is not the one to answer "why is the sky blue";
    // a general model that answered last is.
    if (last != null && last.bestFor.isEmpty) return last;
    return fallback ??
        models.where((ChatModel m) => m.bestFor.isEmpty).firstOrNull;
  }
}

/// Where a message goes: [model] answers it, or [missing] names what it
/// asked for that no connected model can make. Both null means the server
/// chooses.
class ModelRoute {
  const ModelRoute(this.model, {this.missing});

  final ChatModel? model;
  final TaskKind? missing;
}
