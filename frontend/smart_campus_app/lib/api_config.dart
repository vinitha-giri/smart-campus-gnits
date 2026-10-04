import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String baseUrl =
      'https://gnits-smart-campus-api.onrender.com';

  static String get websocketUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';

    return uri.replace(
      scheme: scheme,
      path: '/ws/updates',
      query: null,
    ).toString();
  }

  // Keep this if other existing code uses apiBaseUrl.
  static String get apiBaseUrl => baseUrl;

  // Keep this if other existing code uses isWeb.
  static bool get isWeb => kIsWeb;
}