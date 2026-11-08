import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_admission/api.dart';

void main() {
  test('apply sends the student header and parses the hold', () async {
    late http.BaseRequest seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response(
          jsonEncode({'holdId': 'h_1', 'classId': 'c_1', 'status': 'HELD', 'expiresAt': '2026-11-01T04:10:00.000Z'}), 201);
    });
    final hold = await ApiClient('http://x', client: client).apply('c_1', '20152691234567890');
    expect(seen.headers['X-Student-Id'], '20152691234567890');
    expect(hold.holdId, 'h_1');
  });

  test('server errors become readable messages', () async {
    final client = MockClient((_) async => http.Response(jsonEncode({'error': 'No seats are available in this class.'}), 409));
    expect(
      () => ApiClient('http://x', client: client).apply('c_1', '20152691234567890'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'No seats are available in this class.')),
    );
  });

  test('an unreachable server gives a friendly message', () async {
    final client = MockClient((_) async => throw Exception('socket'));
    expect(() => ApiClient('http://x', client: client).listClasses(),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Cannot reach the server'))));
  });

  test('an overdue HELD hold is shown as EXPIRED immediately', () {
    final h = Hold.fromJson({'holdId': 'h', 'classId': 'c', 'status': 'HELD', 'expiresAt': '2026-11-01T04:10:00.000Z'});
    expect(h.effectiveStatus(DateTime.utc(2026, 11, 1, 4, 9)), 'HELD');
    expect(h.effectiveStatus(DateTime.utc(2026, 11, 1, 4, 11)), 'EXPIRED');
  });
}
