import '../../features/settings/connectors.dart';
import '../../models/models.dart';
import '../repository.dart';
import '../seed.dart';

/// Turning what the server sends into what the app draws.
///
/// Every decoder is forgiving about extra fields and strict about missing
/// ones: a backend is free to send more than the client knows, and a
/// backend that sends less should fail loudly here rather than three
/// screens later.
abstract final class Decode {
  static T _require<T>(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is T) return value;
    throw ShiftApiException(
      ShiftApiErrorKind.malformed,
      'Expected "$key" to be a $T, got ${value.runtimeType}.',
    );
  }

  static List<Map<String, dynamic>> rows(Object? body, String what) {
    // A bare array, or an object with the rows under a key — both are
    // common enough that supporting one and not the other would be an
    // arbitrary demand on the server.
    final Object? list = body is Map<String, dynamic>
        ? (body['data'] ?? body['rows'] ?? body['items'] ?? body[what])
        : body;
    if (list is! List) {
      throw ShiftApiException(
        ShiftApiErrorKind.malformed,
        'Expected a list of $what.',
      );
    }
    return list.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static Creator creator(Map<String, dynamic> json) => Creator(
        handle: _require<String>(json, 'handle'),
        name: _require<String>(json, 'name'),
        email: _require<String>(json, 'email'),
        initials: json['initials'] as String? ??
            initialsOf(_require<String>(json, 'name')),
      );

  /// The trophy shelf is a fixed catalogue with artwork the server does not
  /// have. It sends which are earned and how far along the rest are; the
  /// names, glyphs and tiers stay in the client.
  /// The catalogue — which trophies exist, their names, glyphs and tiers —
  /// is the client's, because it is artwork. How far along *you* are is
  /// the server's, and only the server's.
  ///
  /// So every trophy starts blank and is filled in from the row the
  /// server sent for it. It used to start from the seeded trophy, which
  /// meant an account the server said nothing about inherited the seed's
  /// earned dates and progress — one person's shelf shown to another.
  static List<Trophy> trophies(Object? body) {
    final Map<String, Map<String, dynamic>> byId =
        <String, Map<String, dynamic>>{
      for (final Map<String, dynamic> row in rows(body, 'trophies'))
        if (row['id'] is String) row['id'] as String: row,
    };

    return Seed.trophies.map((Trophy t) {
      final Trophy blank = t.unearned();
      final Map<String, dynamic>? row = byId[t.id];
      if (row == null) return blank;
      return blank.copyWith(
        earnedOn: DateTime.tryParse(row['earnedOn'] as String? ?? ''),
        progress: (row['progress'] as num?)?.toDouble(),
        progressLabel: row['progressLabel'] as String?,
        memberPercent: (row['memberPercent'] as num?)?.toInt(),
      );
    }).toList(growable: false);
  }

  static AgentRun agentRun(Map<String, dynamic> json) => AgentRun(
        id: _require<String>(json, 'id'),
        title: _require<String>(json, 'title'),
        detail: json['detail'] as String? ?? '',
        status: runStatus(json['status'] as String?),
        checksPassed: json['checksPassed'] as bool? ?? false,
        diff: json['diff'] as String?,
        scope: json['scope'] as String?,
      );

  static JobRow job(Map<String, dynamic> json) => JobRow(
        id: _require<String>(json, 'id'),
        title: _require<String>(json, 'title'),
        detail: json['detail'] as String? ?? '',
        status: runStatus(json['status'] as String?),
        scope: json['scope'] as String?,
      );

  static RunStatus runStatus(String? name) => RunStatus.values.firstWhere(
        (RunStatus s) => s.name == name,
        orElse: () => RunStatus.working,
      );

  static DesignDoc design(Map<String, dynamic> json) => DesignDoc(
        id: _require<String>(json, 'id'),
        title: _require<String>(json, 'title'),
        versions: (json['versions'] as num?)?.toInt() ?? 1,
        kindLabel: json['kindLabel'] as String? ?? 'Page',
      );

  static Avatar avatar(Map<String, dynamic> json) => Avatar(
        id: _require<String>(json, 'id'),
        name: json['name'] as String? ?? 'Avatar',
        status: AvatarStatus.values.firstWhere(
          (AvatarStatus s) => s.name == json['status'],
          orElse: () => AvatarStatus.training,
        ),
        personal: json['personal'] as bool? ?? false,
        previewUrl: _still(json['previewUrl']),
        clipUrl: _nonEmpty(json['clipUrl']) ??
            (_isClip(json['previewUrl']) ? json['previewUrl'] as String : null),
        failureReason: _nonEmpty(json['failureReason']),
      );

  static String? _nonEmpty(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  /// A video sent as `previewUrl` (the contract's first draft had an
  /// `.mp4` there) cannot be drawn by `Image.network`: the personal avatar
  /// silently fell back to initials everywhere. It is moved to `clipUrl`
  /// instead, and the picture stays empty until the server sends a still.
  static String? _still(Object? value) {
    final String? url = _nonEmpty(value);
    return url == null || _isClip(url) ? null : url;
  }

  static bool _isClip(Object? value) {
    final String? url = _nonEmpty(value);
    if (url == null) return false;
    final String path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
    return <String>['.mp4', '.mov', '.webm', '.m4v', '.m3u8']
        .any(path.endsWith);
  }

  static Connector connector(Map<String, dynamic> json) => Connector(
        _require<String>(json, 'name'),
        live: json['live'] as bool? ?? false,
      );

  /// Same split as the trophies: which services SHIFT can talk to is the
  /// client's catalogue, and which of them *this account* has authorised
  /// is the server's. A server that names one the client does not know
  /// is added; one the client knows and the server did not name is listed
  /// as not connected, rather than vanishing.
  static List<Connector> connectors(Object? body) {
    final Map<String, bool> live = <String, bool>{
      for (final Map<String, dynamic> row in rows(body, 'connections'))
        if (row['name'] is String)
          row['name'] as String: row['live'] as bool? ?? true,
    };

    final List<Connector> catalogue = ConnectorCatalog.all
        .map((Connector c) => Connector(c.name, live: live[c.name] ?? false))
        .toList();

    final Set<String> known =
        ConnectorCatalog.all.map((Connector c) => c.name).toSet();
    for (final MapEntry<String, bool> entry in live.entries) {
      if (!known.contains(entry.key)) {
        catalogue.add(Connector(entry.key, live: entry.value));
      }
    }
    return catalogue;
  }

  /// Money from the Suite, in cents. Some fields arrive as strings, so
  /// both are read (Rex's notes: "parse with num.parse").
  static int cents(Object? value) => switch (value) {
        final num n => n.round(),
        final String s => num.tryParse(s)?.round() ?? 0,
        _ => 0,
      };

  /// `GET /v1/boards`: `{ "data": { "compete": [...], "crowd": [...], ... } }`.
  /// Each row is `id, display_name, avatar_url, current_tier, tier_name,
  /// is_me, rank` plus that board's cents field. Rows become StandingRows,
  /// in dollars, so the podium, the rivals and the list draw them as they
  /// draw the rest; the Suite does not track movement, and they say so.
  static SuiteBoards boards(Object? body) {
    final Object? data =
        body is Map<String, dynamic> ? (body['data'] ?? body) : null;
    if (data is! Map<String, dynamic>) {
      throw const ShiftApiException(
        ShiftApiErrorKind.malformed,
        'Expected the Suite boards.',
      );
    }
    final Map<SuiteBoard, List<StandingRow>> rows =
        <SuiteBoard, List<StandingRow>>{};
    for (final SuiteBoard board in SuiteBoard.values) {
      final Object? list = data[board.key];
      if (list is! List) continue;
      final List<StandingRow> parsed = <StandingRow>[
        for (final Object? raw in list)
          if (raw is Map<String, dynamic>)
            StandingRow(
              rank: (raw['rank'] as num?)?.toInt() ?? 0,
              name: (raw['display_name'] as String?)?.trim().isNotEmpty ?? false
                  ? (raw['display_name'] as String).trim()
                  : 'Member',
              earnings: cents(raw[board.field]) / 100,
              movement: 0,
              movementKnown: false,
              tier: _tierNamed(raw['tier_name']),
              isYou: raw['is_me'] == true,
              avatarUrl: raw['avatar_url'] is String &&
                      (raw['avatar_url'] as String).isNotEmpty
                  ? raw['avatar_url'] as String
                  : null,
            ),
      ]..sort((StandingRow a, StandingRow b) => a.rank.compareTo(b.rank));
      rows[board] = parsed;
    }
    return SuiteBoards(rows);
  }

  /// The Suite's tier names, where they are one of the four the app draws
  /// in colour. Anything else is left without one rather than guessed.
  static TrophyTier? _tierNamed(Object? name) {
    if (name is! String) return null;
    final String n = name.toLowerCase();
    for (final TrophyTier t in TrophyTier.values) {
      if (n.contains(t.name)) return t;
    }
    return null;
  }
}
