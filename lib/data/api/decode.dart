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
        previewUrl: json['previewUrl'] as String?,
      );

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
}
