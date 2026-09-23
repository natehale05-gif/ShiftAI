import 'dart:convert';

import '../../models/models.dart';

/// What a successful sign-in hands back: the pair of tokens, when the
/// short one dies, and who it belongs to.
class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.creator,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final Creator creator;

  Session copyWith({Creator? creator}) => Session(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
        creator: creator ?? this.creator,
      );

  /// Treated as spent a minute early, so a request never leaves with a
  /// token that expires while it is in flight.
  bool get expired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 1)));

  factory Session.fromJson(Map<String, dynamic> json) {
    final Object? user = json['user'];
    final int seconds = (json['expiresIn'] as num?)?.toInt() ?? 3600;
    return Session(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: DateTime.now().add(Duration(seconds: seconds)),
      creator: user is Map<String, dynamic>
          ? _creator(user)
          : const Creator(handle: '', name: '', email: '', initials: ''),
    );
  }

  static Creator _creator(Map<String, dynamic> json) {
    final String name = json['name'] as String? ?? '';
    return Creator(
      handle: json['handle'] as String? ?? '',
      name: name,
      email: json['email'] as String? ?? '',
      initials: json['initials'] as String? ?? initialsOf(name),
    );
  }

  /// Only ever written to secure storage, never to the preferences blob.
  String encode() => jsonEncode(<String, dynamic>{
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        'creator': <String, String>{
          'handle': creator.handle,
          'name': creator.name,
          'email': creator.email,
          'initials': creator.initials,
        },
      });

  static Session? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      final Map<String, dynamic> who =
          (json['creator'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      return Session(
        accessToken: json['accessToken'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        creator: _creator(who),
      );
    } on Object {
      return null;
    }
  }
}
