import '../../models/models.dart';
import '../api/api_client.dart';
import '../repository.dart';
import 'session.dart';
import 'token_store.dart';

/// The four routes in `docs/API.md` under "Auth", and nothing else.
abstract interface class AuthService {
  Future<Session> signIn({required String email, required String password});
  Future<Session> refresh(String refreshToken);
  Future<void> signOut(String refreshToken);
  Future<void> deleteAccount();
}

class HttpAuthService implements AuthService {
  const HttpAuthService(this._api);

  static const String _signIn = '/v1/auth/sign-in';
  static const String _refresh = '/v1/auth/refresh';
  static const String _signOut = '/v1/auth/sign-out';
  static const String _me = '/v1/me';

  final ApiClient _api;

  @override
  Future<Session> signIn({
    required String email,
    required String password,
  }) async =>
      Session.fromJson(
        await _api.post(
          _signIn,
          body: <String, String>{'email': email, 'password': password},
        ) as Map<String, dynamic>,
      );

  @override
  Future<Session> refresh(String refreshToken) async => Session.fromJson(
        await _api.post(
          _refresh,
          body: <String, String>{'refreshToken': refreshToken},
        ) as Map<String, dynamic>,
      );

  @override
  Future<void> signOut(String refreshToken) =>
      _api.post(_signOut, body: <String, String>{
        'refreshToken': refreshToken,
      });

  @override
  Future<void> deleteAccount() => _api.delete(_me);
}

/// With no engine configured, the gate still has to open — otherwise the
/// app cannot be run at all without a server. It accepts any well-formed
/// pair and signs you in as the seeded creator. It is never reachable in
/// a build with a base URL set.
class SeedAuthService implements AuthService {
  const SeedAuthService(this._creator);

  final Creator _creator;

  @override
  Future<Session> signIn({
    required String email,
    required String password,
  }) async {
    if (password.isEmpty) {
      throw const ShiftApiException(
        ShiftApiErrorKind.unauthorised,
        'That email and password do not match.',
        status: 401,
      );
    }
    return Session(
      accessToken: 'seed-access',
      refreshToken: 'seed-refresh',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      creator: _creator,
    );
  }

  @override
  Future<Session> refresh(String refreshToken) =>
      signIn(email: _creator.email, password: 'seed');

  @override
  Future<void> signOut(String refreshToken) async {}

  @override
  Future<void> deleteAccount() async {}
}

/// Holds the session, hands the access token to [ApiClient], and owns the
/// one rule that matters: refresh once, then sign out.
class AuthController {
  AuthController({
    required AuthService service,
    required TokenStore store,
  })  : _service = service,
        _store = store;

  final AuthService _service;
  final TokenStore _store;

  Session? _session;
  Future<Session?>? _inFlight;

  Session? get session => _session;
  bool get signedIn => _session != null;
  Creator? get creator => _session?.creator;

  /// Read once at start. A stored session that has already expired is not
  /// thrown away — the first call refreshes it.
  Future<void> restore() async {
    _session = await _store.read();
  }

  /// What [ApiClient.tokenProvider] calls before every request.
  Future<String?> token() async {
    final Session? held = _session;
    if (held == null) return null;
    if (!held.expired) return held.accessToken;
    final Session? fresh = await _refreshOnce();
    return fresh?.accessToken;
  }

  /// What [ApiClient.onUnauthorised] calls when the engine rejects a token
  /// the client thought was good.
  Future<String?> recover() async => (await _refreshOnce())?.accessToken;

  /// Concurrent calls share one refresh rather than each starting theirs —
  /// ten screens loading at once must not fire ten refreshes, which a
  /// server that rotates refresh tokens would reject nine of.
  Future<Session?> _refreshOnce() {
    return _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);
  }

  Future<Session?> _doRefresh() async {
    final String? token = _session?.refreshToken;
    if (token == null || token.isEmpty) return null;
    try {
      final Session fresh = await _service.refresh(token);
      _session = fresh;
      await _store.write(fresh);
      return fresh;
    } on ShiftApiException {
      // A refresh token the server will not honour is the end of the
      // session. Clearing here is what stops the retry loop.
      await forget();
      return null;
    }
  }

  Future<Session> signIn({
    required String email,
    required String password,
  }) async {
    final Session fresh =
        await _service.signIn(email: email, password: password);
    _session = fresh;
    await _store.write(fresh);
    return fresh;
  }

  /// Revokes server-side if it can, and forgets locally either way — a
  /// sign-out that fails on the network still has to sign you out here.
  Future<void> signOut() async {
    final String? token = _session?.refreshToken;
    if (token != null && token.isNotEmpty) {
      try {
        await _service.signOut(token);
      } on ShiftApiException {
        // Nothing to tell the person: they are signed out regardless.
      }
    }
    await forget();
  }

  /// Apple requires this to be reachable from inside the app.
  Future<void> deleteAccount() async {
    await _service.deleteAccount();
    await forget();
  }

  Future<void> forget() async {
    _session = null;
    await _store.clear();
  }

  /// Folds a profile change into the held session, so the tokens survive it
  /// and a restart still shows the new handle. A no-op if signed out.
  Future<void> updateCreator(Creator next) async {
    final Session? held = _session;
    if (held == null) return;
    final Session updated = held.copyWith(creator: next);
    _session = updated;
    await _store.write(updated);
  }
}
