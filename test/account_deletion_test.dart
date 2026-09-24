import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shift_ai/data/api/api_client.dart';
import 'package:shift_ai/data/auth/auth_service.dart';

ApiClient _answering(int status, [Object? body]) => ApiClient(
      baseUrl: 'https://api.example.com',
      client: MockClient((http.Request request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/v1/me');
        return http.Response(body == null ? '' : jsonEncode(body), status);
      }),
    );

void main() {
  test('204: gone, nothing more to say', () async {
    expect(await HttpAuthService(_answering(204)).deleteAccount(), isNull);
  });

  test('202: queued, and the server says when', () async {
    final ApiClient api = _answering(
      202,
      <String, String>{'message': 'Your account will be deleted on 3 October.'},
    );
    expect(await HttpAuthService(api).deleteAccount(),
        'Your account will be deleted on 3 October.');
  });
}
