import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Backend URL: --dart-define=API_URL=... > saved setting > platform default
/// (the Android emulator reaches the host machine at 10.0.2.2).
String defaultApiUrl() {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8080';
  return 'http://localhost:8080';
}

class AppState extends ChangeNotifier {
  AppState(this.api);
  final ApiClient api;
  SharedPreferences? _prefs;
  String studentInput = '';

  String? get student => studentIdRx.hasMatch(studentInput.trim()) ? studentInput.trim() : null;
  String? get studentError =>
      studentInput.trim().isNotEmpty && student == null ? 'The birth registration number must be exactly 17 digits.' : null;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    studentInput = _prefs!.getString('studentId') ?? '';
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isEmpty) api.baseUrl = _prefs!.getString('apiUrl') ?? api.baseUrl;
    notifyListeners();
  }

  void setStudent(String v) {
    studentInput = v;
    _prefs?.setString('studentId', v);
    notifyListeners();
  }

  void setApiUrl(String v) {
    api.baseUrl = v.trim();
    _prefs?.setString('apiUrl', api.baseUrl);
    notifyListeners();
  }
}
