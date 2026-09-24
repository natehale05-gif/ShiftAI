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

  /// [wait] replaces [timeout] for one call that is expected to take
  /// longer (a model writing a long answer, or making a file). Completing
  /// [abort] cancels the request, and the call throws.
  Future<dynamic> post(
    String path, {
    Object? body,
    Duration? wait,
    Future<void>? abort,
  }) {
    if (abort == null) {
      return _send(() async => _client
          .post(
            _uri(path),
            headers: await _headers(),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(wait ?? timeout));
    }
    return _send(() async {
      final http.AbortableRequest request =
          http.AbortableRequest('POST', _uri(path), abortTrigger: abort)
            ..headers.addAll(await _headers());
      if (body != null) request.body = jsonEncode(body);
      final http.StreamedResponse streamed =
          await _client.send(request).timeout(wait ?? timeout);
      return http.Response.fromStream(streamed);
    });
  }

  /// A post whose answer may arrive as it is written.
  ///
  /// It asks for `text/event-stream` as well as JSON. A server that
  /// streams sends `text` events, each `{"text": "<the next words>"}`,
  /// handed to [onText] as they land, then one `messages` event with the
  /// finished answer, which is what this returns; an `error` event is
  /// thrown as a server error. A server that does not stream answers JSON
  /// as usual and [onText] is never called. A stream that ends with no
  /// `messages` event returns null.
  ///
  /// [wait] is how long the server may take to start answering, and then
  /// how long it may go quiet mid-answer. [abort] cancels, as for [post].
  Future<dynamic> postEvents(
    String path, {
    Object? body,
    Duration? wait,
    Future<void>? abort,
    void Function(String text)? onText,
  }) async {
    final Duration limit = wait ?? timeout;
    Future<http.StreamedResponse> open() async {
      final http.AbortableRequest request =
          http.AbortableRequest('POST', _uri(path), abortTrigger: abort)
            ..headers.addAll(await _headers())
            ..headers['Accept'] = 'text/event-stream, application/json';
      if (body != null) request.body = jsonEncode(body);
      return _client.send(request).timeout(limit);
    }

    Future<http.StreamedResponse> guarded(
      Future<http.StreamedResponse> Function() run,
    ) async {
      try {
        return await run();
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
    }

    http.StreamedResponse response = await guarded(open);
    if (response.statusCode == 401 && onUnauthorised != null) {
      await response.stream.drain<void>();
      final String? fresh = await onUnauthorised!();
      if (fresh != null && fresh.isNotEmpty) response = await guarded(open);
    }
    final String type = response.headers['content-type'] ?? '';
    final bool ok = response.statusCode >= 200 && response.statusCode < 300;
    if (!ok || !type.startsWith('text/event-stream')) {
      final http.Response whole;
      try {
        whole = await http.Response.fromStream(response);
      } on Object catch (error) {
        throw ShiftApiException(
          ShiftApiErrorKind.offline,
          'The answer was cut off. $error',
        );
      }
      return _decode(whole);
    }
    return _readEvents(response.stream, limit: limit, onText: onText);
  }

  /// Server-sent events, one `event:` and its `data:` lines per blank-line
  /// separated block.
  static Future<dynamic> _readEvents(
    Stream<List<int>> bytes, {
    required Duration limit,
    void Function(String text)? onText,
  }) async {
    String event = 'message';
    final List<String> data = <String>[];
    dynamic finished;

    void dispatch() {
      if (data.isEmpty) {
        event = 'message';
        return;
      }
      final String raw = data.join('\n');
      data.clear();
      final String name = event;
      event = 'message';
      final Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        throw const ShiftApiException(
          ShiftApiErrorKind.malformed,
          'The server sent an event that is not JSON.',
        );
      }
      switch (name) {
        case 'text':
          final Object? text =
              decoded is Map<String, dynamic> ? decoded['text'] : null;
          if (text is String && text.isNotEmpty) onText?.call(text);
        case 'messages':
          finished = decoded;
        case 'error':
          throw ShiftApiException(
            ShiftApiErrorKind.server,
            (decoded is Map<String, dynamic> ? _firstMessage(decoded) : null) ??
                'The answer stopped part way.',
          );
      }
    }

    try {
      await for (final String line in bytes
          .timeout(limit)
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())) {
        if (line.isEmpty) {
          dispatch();
        } else if (line.startsWith(':')) {
          // A comment: servers send these to keep the connection open.
        } else if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final String value = line.substring(5);
          data.add(value.startsWith(' ') ? value.substring(1) : value);
        }
      }
      dispatch();
    } on ShiftApiException {
      rethrow;
    } on TimeoutException {
      throw const ShiftApiException(
        ShiftApiErrorKind.timeout,
        'The answer stopped coming.',
      );
    } on Object catch (error) {
      throw ShiftApiException(
        ShiftApiErrorKind.offline,
        'The answer was cut off. $error',
      );
    }
    return finished;
  }

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() async => _client
          .patch(
            _uri(path),
            headers: await _headers(),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout));

  Future<dynamic> put(String path, {Object? body}) => _send(() async => _client
      .put(
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
    Duration? wait,
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
            await _client.send(request).timeout(wait ?? timeout);
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
    return _decode(response);
  }

  /// A whole response as JSON, or the [ShiftApiException] its status means.
  static dynamic _decode(http.Response response) {
    final int status = response.statusCode;
    // JSON is UTF-8 by definition (RFC 8259), whatever the Content-Type
    // says. response.body decodes by the header and falls back to
    // Latin-1 when it names no charset and is not application/json, so a
    // proxy's text/plain turned "1080 × 1920" into "1080 Ã 1920", and
    // every accent, dash and emoji with it.
    final String text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (status >= 200 && status < 300) {
      if (text.isEmpty) return null;
      try {
        return jsonDecode(text);
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
      _messageFrom(text) ?? 'The request failed.',
      status: status,
    );
  }

  /// Servers put the reason in different places. Try the common ones, and
  /// fall back to nothing rather than showing raw JSON to a person.
  static String? _messageFrom(String body) {
    if (body.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return _firstMessage(decoded);
    } on FormatException {
      // Not JSON; nothing useful to show.
    }
    return null;
  }

  static String? _firstMessage(Map<String, dynamic> body) {
    for (final String key in <String>['message', 'error', 'detail']) {
      final Object? value = body[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  void close() => _client.close();
}
