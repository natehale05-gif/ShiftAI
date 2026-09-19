import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session.dart';

/// Where the tokens live. Keychain on iOS, the Keystore-backed
/// EncryptedSharedPreferences on Android, WebCrypto in the browser —
/// never the `shift.app.v1` preferences blob, which is plain text and
/// gets backed up with everything else on the device.
abstract interface class TokenStore {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore([this._storage = _default]);

  // Android's default is the Keystore-backed cipher now; the old
  // EncryptedSharedPreferences flag is deprecated and ignored.
  // first_unlock keeps the token readable after a reboot the person has
  // unlocked once, and unreadable on a locked device.
  static const FlutterSecureStorage _default = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _key = 'shift.session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<Session?> read() async {
    try {
      return Session.decode(await _storage.read(key: _key));
    } on Object {
      // A keychain that will not open is a signed-out app, not a crash on
      // launch. The person signs in again.
      return null;
    }
  }

  @override
  Future<void> write(Session session) async {
    try {
      await _storage.write(key: _key, value: session.encode());
    } on Object {
      // Nothing to do but carry on with the session in memory: it lasts
      // until the app closes, which beats refusing to sign in at all.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object {
      // Ignored deliberately — the caller has already dropped its copy.
    }
  }
}

/// What the tests bind to, and what a build with no platform channels
/// gets: a store that keeps the session for as long as the process lives.
class MemoryTokenStore implements TokenStore {
  Session? _held;

  @override
  Future<Session?> read() async => _held;

  @override
  Future<void> write(Session session) async => _held = session;

  @override
  Future<void> clear() async => _held = null;
}
