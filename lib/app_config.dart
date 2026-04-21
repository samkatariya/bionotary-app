import 'package:flutter/foundation.dart';

/// Backend base URL. Override per build, e.g.:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000`
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get resolvedApiBaseUrl {
    if (apiBaseUrl.isNotEmpty) return apiBaseUrl;
    if (kIsWeb) return 'http://localhost:5000';
    return 'http://10.0.2.2:5000';
  }
}
