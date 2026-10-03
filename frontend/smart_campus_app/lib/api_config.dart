import 'package:flutter/foundation.dart';

/// Production API configuration for GNITS Smart Campus.
class ApiConfig {
  static const String baseUrl =
      'https://gnits-smart-campus-api.onrender.com';

  static String get websocketUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';

    return uri
        .replace(
          scheme: scheme,
          path: '/ws/updates',
          query: null,
        )
        .toString();
  }
}