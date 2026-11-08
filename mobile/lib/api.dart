import 'dart:convert';

import 'package:http/http.dart' as http;

class ClassInfo {
  final String id, name;
  final int totalSeats, heldSeats, confirmedSeats, availableSeats;
  ClassInfo.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        totalSeats = j['totalSeats'],
        heldSeats = j['heldSeats'],
        confirmedSeats = j['confirmedSeats'],
        availableSeats = j['availableSeats'];
}

class Hold {
  final String holdId, classId, status;
  final String? className;
  final DateTime expiresAt;
  Hold.fromJson(Map<String, dynamic> j)
      : holdId = j['holdId'],
        classId = j['classId'],
        className = j['className'],
        status = j['status'],
        expiresAt = DateTime.parse(j['expiresAt']).toUtc();

  /// Server status, except a HELD hold whose time ran out is shown as EXPIRED straight away.
  String effectiveStatus(DateTime now) =>
      status == 'HELD' && !expiresAt.isAfter(now.toUtc()) ? 'EXPIRED' : status;
}

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);
  @override
  String toString() => message;
}

const _fallback = {
  400: 'Some of the information you entered is not valid. Please check it and try again.',
  404: 'We could not find that item. It may have been removed.',
  409: 'That action is not possible right now (for example, no seats left or the time has run out).',
  500: 'Something went wrong on the server. Please try again in a moment.',
  502: 'The server is temporarily unavailable. Please try again in a moment.',
  503: 'The server is temporarily unavailable. Please try again in a moment.',
};

final studentIdRx = RegExp(r'^\d{17}$');

class ApiClient {
  String baseUrl;
  final http.Client _http;
  ApiClient(this.baseUrl, {http.Client? client}) : _http = client ?? http.Client();

  Future<dynamic> _send(String method, String path, {String? student, Object? body}) async {
    final uri = Uri.parse(baseUrl.replaceAll(RegExp(r'/+$'), '') + path);
    final headers = <String, String>{
      'Content-Type': ?(body != null ? 'application/json' : null),
      'X-Student-Id': ?student,
    };
    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 20)));
    } catch (_) {
      throw ApiException('Cannot reach the server. Please check your internet connection and the server address, then try again.', 0);
    }
    if (res.statusCode == 204) return null;
    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {}
    if (res.statusCode >= 400) {
      final msg = data is Map ? data['error'] as String? : null;
      throw ApiException(msg ?? _fallback[res.statusCode] ?? 'Unexpected error (${res.statusCode}). Please try again.', res.statusCode);
    }
    return data;
  }

  Future<List<ClassInfo>> listClasses() async =>
      ((await _send('GET', '/classes')) as List).map((e) => ClassInfo.fromJson(e)).toList();

  Future<void> createClass(String name, int seats) => _send('POST', '/classes', body: {'name': name, 'totalSeats': seats});

  Future<Hold> apply(String classId, String student) async =>
      Hold.fromJson(await _send('POST', '/classes/$classId/holds', student: student));

  Future<Hold> getHold(String holdId) async => Hold.fromJson(await _send('GET', '/holds/$holdId'));

  Future<void> confirm(String holdId, String student) => _send('POST', '/holds/$holdId/confirm', student: student);

  Future<void> cancel(String holdId, String student) => _send('DELETE', '/holds/$holdId', student: student);

  Future<List<Hold>> myHolds(String student) async =>
      ((await _send('GET', '/me/holds', student: student)) as List).map((e) => Hold.fromJson(e)).toList();
}
