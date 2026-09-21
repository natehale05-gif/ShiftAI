import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../repository.dart';

/// The one place that talks to the network.
///
/// Everything above it deals in models and [ShiftApiException]; nothing
/// above it sees a status code, a header or a JSON map. Auth is a callback
/// rather than a stored string so a token can be refreshed without this
/// object knowing how that works.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.tokenProvider,
    this.timeout = const Duration(seconds: 20),
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Where the engine lives, e.g. `https://api.shiftai.club`. A trailing
  /// slash is tolerated.
  final String baseUrl;

  /// Returns the bearer token to send, or null while signed out.
  ///
  /// Settable because the thing that provides tokens is built on top of
  /// this client, so the two are tied together after both exist.
  FutureOr<String?> Function()? tokenProvider;

  /// Called once when the engine answers 401. Returning a fresh token
  /// replays the request with it; returning null gives up and the 401
  /// surfaces as `unauthorised`, which is the signal to sign out.
  ///
  /// Set after construction because the thing that refreshes tokens is
  /// built on top of this client.
  Future<String?> Function()? onUnauthorised;

  final Duration timeout;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final String root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final String tail = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$root$tail').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final String? token = await tokenProvider?.call();
    return <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() async => _client
          .get(_uri(path, query), headers: await _headers(json: false))
          .timeout(timeout));

  Future<dynamic> post(String path, {Object? body}) => _send(() async => _client
      .post(
        _uri(path),
        headers: await _headers(),
        body: body == null ? null : jsonEncode(body),
      )
      .timeout(timeout));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() async => _client
          .patch(
            _uri(path),
            headers: await _headers(),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout));

  Future<dynamic> delete(String path) => _send(() async =>
      _client.delete(_uri(path), headers: await _headers()).timeout(timeout));

  /// Sends bytes as multipart. Used for attachments and the avatar.
  Future<dynamic> upload(
    String path, {
    required String field,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) =>
      _send(() async {
        final http.MultipartRequest request =
            http.MultipartRequest('POST', _uri(path))
              ..headers.addAll(await _headers(json: false))
              ..files.add(
                http.MultipartFile.fromBytes(
                  field,
                  bytes,
                  filename: fileName,
                  contentType: _mediaType(mimeType),
                ),
              );
        final http.StreamedResponse streamed =
            await _client.send(request).timeout(timeout);
        return http.Response.fromStream(streamed);
      });

  static http.MediaType? _mediaType(String mimeType) {
    final List<String> parts = mimeType.split('/');
    if (parts.length != 2) return null;
    return http.MediaType(parts.first, parts.last);
  }

  /// Runs a request and turns everything that can go wrong into one
  /// exception type, so no call site has to read a status code.
  ///
  /// A 401 is the one status this retries: it refreshes once and replays.
  /// Once, never in a loop — a refresh endpoint that itself 401s would
  /// otherwise hammer the server on every screen.
  Future<dynamic> _send(
    Future<http.Response> Function() run, {
    bool allowRetry = true,
  }) async {
    late final http.Response response;
    try {
      response = await run();
    } on TimeoutException {
      throw const ShiftApiException(
        ShiftApiErrorKind.timeout,
        'The server did not answer in time.',
      );
    } on Object catch (error) {
      throw ShiftApiException(
        ShiftApiErrorKind.offline,
        'Could not reach the server. $error',
      );
    }

    final int status = response.statusCode;
    if (status == 401 && allowRetry && onUnauthorised != null) {
      final String? fresh = await onUnauthorised!();
      if (fresh != null && fresh.isNotEmpty) {
        return _send(run, allowRetry: false);
      }
    }
    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } on FormatException {
        throw ShiftApiException(
          ShiftApiErrorKind.malformed,
          'The server sent something that is not JSON.',
          status: status,
        );
      }
    }

    throw ShiftApiException(
      switch (status) {
        401 => ShiftApiErrorKind.unauthorised,
        403 => ShiftApiErrorKind.forbidden,
        404 => ShiftApiErrorKind.notFound,
        >= 400 && < 500 => ShiftApiErrorKind.badRequest,
        _ => ShiftApiErrorKind.server,
      },
      _messageFrom(response.body) ?? 'The request failed.',
      status: status,
    );
  }

  /// Servers put the reason in different places. Try the common ones, and
  /// fall back to nothing rather than showing raw JSON to a person.
  static String? _messageFrom(String body) {
    if (body.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        for (final String key in <String>['message', 'error', 'detail']) {
          final Object? value = decoded[key];
          if (value is String && value.isNotEmpty) return value;
        }
      }
    } on FormatException {
      // Not JSON; nothing useful to show.
    }
    return null;
  }

  void close() => _client.close();
}
