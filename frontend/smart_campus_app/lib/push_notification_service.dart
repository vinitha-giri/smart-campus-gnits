import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';
import 'session_manager.dart';

class PushNotificationService {
  static bool _started=false;
  static StreamSubscription<String>? _tokenSub;

  static Future<void> initialize() async {
    if (kIsWeb || _started || SessionManager.email.isEmpty || SessionManager.token.isEmpty) return;
    _started=true;
    try {
      await Firebase.initializeApp();
      final messaging=FirebaseMessaging.instance;
      await messaging.requestPermission(alert:true,badge:true,sound:true,provisional:false);
      final token=await messaging.getToken();
      if(token!=null && token.isNotEmpty) await _register(token);
      await _tokenSub?.cancel();
      _tokenSub=messaging.onTokenRefresh.listen((token){_register(token);});
    } catch (_) {
      // Android push is optional until the Firebase Android app is configured.
    }
  }

  static Future<void> _register(String token) async {
    try {
      await http.post(Uri.parse('${ApiConfig.baseUrl}/api/devices/register'),headers:{'Content-Type':'application/json'},body:jsonEncode({'email':SessionManager.email,'sessionToken':SessionManager.token,'token':token})).timeout(const Duration(seconds:8));
    } catch (_) {}
  }

  static Future<void> dispose() async { await _tokenSub?.cancel(); _tokenSub=null; _started=false; }
}
