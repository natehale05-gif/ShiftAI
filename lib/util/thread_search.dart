import '../models/models.dart';

/// The saved chats a Recents search keeps: every word typed has to appear
/// in the chat's title or in something said in it, yours or a reply, in
/// any case and any order. "ferry caption" finds the chat where a caption
/// for the ferry clip was written, whatever it was called.
List<ChatThread> threadMatches(List<ChatThread> threads, String query) {
  final List<String> words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return threads;
  return threads.where((ChatThread t) {
    final String haystack = <String>[
      t.title,
      for (final ChatMessage m in t.messages) ...<String>[
        m.body,
        ...m.bullets,
        for (final SentFile f in m.files) f.name,
      ],
    ].join(' ').toLowerCase();
    return words.every(haystack.contains);
  }).toList(growable: false);
}
