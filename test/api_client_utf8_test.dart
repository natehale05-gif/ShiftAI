import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shift_ai/data/api/api_client.dart';
import 'package:shift_ai/data/repository.dart';

/// Answers every request with [bytes] under [contentType], or with no
/// Content-Type at all.
class _Client extends http.BaseClient {
  _Client(this.bytes, {this.status = 200, this.contentType});
  final List<int> bytes;
  final int status;
  final String? contentType;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream<List<int>>.value(bytes),
        status,
        request: request,
        headers: <String, String>{
          if (contentType != null) 'content-type': contentType!,
        },
      );
}

void main() {
  const String text = 'Format: vertical 1080 × 1920 — Café 🎬';
  final List<int> bytes = utf8.encode(jsonEncode(<String, String>{
    'prompt': text,
  }));

  for (final String? type in <String?>[
    null,
    'text/plain',
    'text/html',
    'application/json',
    'application/json; charset=utf-8',
  ]) {
    test('JSON is read as UTF-8 under ${type ?? 'no Content-Type'}', () async {
      final ApiClient api = ApiClient(
        baseUrl: 'https://api.example.com',
        client: _Client(bytes, contentType: type),
      );
      final dynamic body = await api.get('/v1/anything');
      // Latin-1 would give "1080 Ã 1920 â Café ð¬".
      expect((body as Map<String, dynamic>)['prompt'], text);
    });
  }

  test('an error message is read as UTF-8 too', () async {
    final ApiClient api = ApiClient(
      baseUrl: 'https://api.example.com',
      client: _Client(
        utf8.encode('{"message":"Café is closed — try later."}'),
        status: 400,
        contentType: 'text/plain',
      ),
    );
    await expectLater(
      api.get('/v1/anything'),
      throwsA(isA<ShiftApiException>().having(
        (ShiftApiException e) => e.message,
        'message',
        'Café is closed — try later.',
      )),
    );
  });
}
