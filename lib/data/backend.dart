import 'api/api_client.dart';
import 'api/http_repository.dart';
import 'auth/auth_service.dart';
import 'auth/token_store.dart';
import 'repository.dart';
import 'seed.dart';
import 'seed_repository.dart';

/// The engine, assembled. One base URL decides everything: with one, the
/// app reads and writes over HTTP and signs in for real; without one, it
/// runs on the seeded catalogue and a gate that lets you through.
///
/// Built here rather than in [AppState] so the client, the repository and
/// the auth controller are wired to each other exactly once — the token
/// callbacks are circular, and getting them wrong means either every
/// request goes out unsigned or a 401 loops.
class Backend {
  Backend({
    required this.repository,
    required this.auth,
    required this.seeded,
  });

  final ShiftRepository repository;
  final AuthController auth;

  /// True when nothing is behind this but the seeded catalogue.
  final bool seeded;

  static Future<Backend> connect(
    String? baseUrl, {
    TokenStore? store,
  }) async {
    final String url = baseUrl?.trim() ?? '';
    final TokenStore tokens = store ?? const SecureTokenStore();

    if (url.isEmpty) {
      final AuthController auth = AuthController(
        service: const SeedAuthService(Seed.creator),
        store: tokens,
      );
      await auth.restore();
      return Backend(
        repository: SeedRepository(),
        auth: auth,
        seeded: true,
      );
    }

    final ApiClient api = ApiClient(baseUrl: url);
    final AuthController auth = AuthController(
      service: HttpAuthService(api),
      store: tokens,
    );
    await auth.restore();

    // The client asks the controller for a token; the controller asks the
    // client to refresh. Tying the knot after both exist is the only way
    // round that.
    api
      ..tokenProvider = auth.token
      ..onUnauthorised = auth.recover;

    return Backend(
      repository: HttpRepository(api),
      auth: auth,
      seeded: false,
    );
  }

  /// For tests: a seeded engine with an in-memory keychain.
  static Future<Backend> seedOnly({Duration replyDelay = Duration.zero}) async {
    final AuthController auth = AuthController(
      service: const SeedAuthService(Seed.creator),
      store: MemoryTokenStore(),
    );
    await auth.restore();
    return Backend(
      repository: SeedRepository(replyDelay: replyDelay),
      auth: auth,
      seeded: true,
    );
  }
}
